--------------------------------------------------------------------------------
-- FUNCTION aou ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION aou (
  pUserId       uuid,
  OUT object    uuid,
  OUT deny      bit,
  OUT allow     bit,
  OUT mask      bit
) RETURNS       SETOF record
AS $$
  WITH member_group AS (
      SELECT pUserId AS userid UNION SELECT userid FROM db.member_group WHERE member = pUserId
  )
  SELECT a.object, bit_or(a.deny), bit_or(a.allow), bit_or(a.mask)
    FROM db.aou a INNER JOIN member_group m ON a.userid = m.userid
   GROUP BY a.object;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION aou ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION aou (
  pUserId       uuid,
  pObject       uuid,
  OUT object    uuid,
  OUT deny      bit,
  OUT allow     bit,
  OUT mask      bit
) RETURNS       SETOF record
AS $$
  WITH member_group AS (
      SELECT pUserId AS userid UNION SELECT userid FROM db.member_group WHERE member = pUserId
  )
  SELECT a.object, bit_or(a.deny), bit_or(a.allow), bit_or(a.mask)
    FROM db.aou a INNER JOIN member_group m ON a.userid = m.userid
     AND a.object = pObject
   GROUP BY a.object
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectMask ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectMask (
  pObject	uuid,
  pUserId	uuid DEFAULT current_userid()
) RETURNS	bit
AS $$
  SELECT CASE
         WHEN pUserId = o.owner THEN SubString(mask FROM 1 FOR 3)
         WHEN EXISTS (SELECT id FROM db.user WHERE id = pUserId AND type = 'G') THEN SubString(mask FROM 4 FOR 3)
         ELSE SubString(mask FROM 7 FOR 3)
         END
    FROM db.aom a INNER JOIN db.object o ON o.id = a.object
   WHERE object = pObject
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectAccessMask ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectAccessMask (
  pObject	uuid,
  pUserId	uuid DEFAULT current_userid()
) RETURNS	bit
AS $$
  SELECT mask FROM aou(pUserId, pObject)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckObjectAccess -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckObjectAccess (
  pObject	uuid,
  pMask		bit,
  pUserId	uuid DEFAULT current_userid()
) RETURNS	boolean
AS $$
BEGIN
  RETURN coalesce(coalesce(GetObjectAccessMask(pObject, pUserId), GetObjectMask(pObject, pUserId)) & pMask = pMask, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DecodeObjectAccess ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DecodeObjectAccess (
  pObject	uuid,
  pUserId	uuid DEFAULT current_userid(),
  OUT s		boolean,
  OUT u		boolean,
  OUT d		boolean
) RETURNS 	record
AS $$
DECLARE
  bMask		bit(3);
BEGIN
  bMask := coalesce(GetObjectAccessMask(pObject, pUserId), GetObjectMask(pObject, pUserId));

  s := bMask & B'100' = B'100';
  u := bMask & B'010' = B'010';
  d := bMask & B'001' = B'001';
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectMembers ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectMembers (
  pObject	uuid
) RETURNS 	SETOF ObjectMembers
AS $$
  SELECT * FROM ObjectMembers WHERE object = pObject;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- chmodo ----------------------------------------------------------------------
--------------------------------------------------------------------------------
/*
 * Устанавливает битовую маску доступа для объекта и пользователя.
 * @param {uuid} pObject - Идентификатор объекта
 * @param {bit} pMask - Маска доступа. Шесть бит (d:{sud}a:{sud}) где: d - запрещающие биты; a - разрешающие биты: {s - select, u - update, d - delete}
 * @param {uuid} pUserId - Идентификатор пользователя/группы
 * @return {void}
*/
CREATE OR REPLACE FUNCTION chmodo (
  pObject       uuid,
  pMask         bit,
  pUserId       uuid DEFAULT current_userid()
) RETURNS       void
AS $$
DECLARE
  bDeny         bit(3);
  bAllow        bit(3);
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  pMask := NULLIF(pMask, B'000000');

  IF pMask IS NOT NULL THEN
    bDeny := coalesce(SubString(pMask FROM 1 FOR 3), B'000');
    bAllow := coalesce(SubString(pMask FROM 4 FOR 3), B'000');

	INSERT INTO db.aou SELECT pObject, pUserId, bDeny, bAllow
	  ON CONFLICT (object, userid) DO UPDATE SET deny = bDeny, allow = bAllow;
  ELSE
    DELETE FROM db.aou WHERE object = pObject AND userid = pUserId;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AccessObjectUser ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AccessObjectUser (
  pEntity	uuid,
  pUserId	uuid DEFAULT current_userid()
) RETURNS TABLE (
    object  uuid
)
AS $$
  WITH _membergroup AS (
      SELECT pUserId AS userid UNION SELECT userid FROM db.member_group WHERE member = pUserId
  )
  SELECT a.object
    FROM db.aou a INNER JOIN _membergroup m ON a.userid = m.userid AND a.entity = pEntity
   GROUP BY a.object
  HAVING bit_or(a.mask) & B'100' = B'100'
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateObject ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateObject (
  pParent	uuid,
  pType     uuid,
  pLabel	text DEFAULT null,
  pText		text DEFAULT null,
  pLocale	uuid DEFAULT current_locale()
) RETURNS 	uuid
AS $$
DECLARE
  uId		uuid;
BEGIN
  INSERT INTO db.object (parent, type)
  VALUES (pParent, pType)
  RETURNING id INTO uId;

  INSERT INTO db.object_text (object, locale, label, text)
  VALUES (uId, pLocale, pLabel, pText);

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditObject ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditObject (
  pId		uuid,
  pParent	uuid DEFAULT null,
  pType		uuid DEFAULT null,
  pLabel	text DEFAULT null,
  pText		text DEFAULT null,
  pLocale	uuid DEFAULT current_locale()
) RETURNS	void
AS $$
BEGIN
  UPDATE db.object
     SET type = coalesce(pType, type),
         parent = CheckNull(coalesce(pParent, parent, null_uuid()))
   WHERE id = pId;

  UPDATE db.object_text
     SET label = CheckNull(coalesce(pLabel, label, '<null>')),
         text = CheckNull(coalesce(pText, text, '<null>'))
   WHERE object = pId
     AND locale = pLocale;

  IF NOT FOUND THEN
	INSERT INTO db.object_text (object, locale, label, text)
	VALUES (pId, pLocale, pLabel, pText);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetObjectParent -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetObjectParent (
  nObject	uuid,
  pParent	uuid
) RETURNS	void
AS $$
BEGIN
  UPDATE db.object SET parent = pParent WHERE id = nObject;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectEntity -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectEntity (
  nObject	uuid
) RETURNS	uuid
AS $$
DECLARE
  nEntity	uuid;
BEGIN
  SELECT entity INTO nEntity FROM db.object WHERE id = nObject;
  RETURN nEntity;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectParent -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectParent (
  nObject	uuid
) RETURNS	uuid
AS $$
DECLARE
  nParent	uuid;
BEGIN
  SELECT parent INTO nParent FROM db.object WHERE id = nObject;
  RETURN nParent;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectLabel -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectLabel (
  pObject	uuid,
  pLocale	uuid DEFAULT current_locale()
) RETURNS	text
AS $$
DECLARE
  vLabel	text;
BEGIN
  SELECT label INTO vLabel FROM db.object_text WHERE object = pObject AND locale = pLocale;
  RETURN vLabel;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetObjectLabel -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetObjectLabel (
  pObject	uuid,
  pLabel    text,
  pLocale	uuid DEFAULT current_locale()
) RETURNS	void
AS $$
BEGIN
  UPDATE db.object_text SET label = pLabel WHERE object = pObject AND locale = pLocale;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectClass -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectClass (
  pId		uuid
) RETURNS	uuid
AS $$
DECLARE
  nClass	uuid;
BEGIN
  SELECT class INTO nClass FROM db.object WHERE id = pId;
  RETURN nClass;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectType ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectType (
  pId		uuid
) RETURNS	uuid
AS $$
DECLARE
  nType		uuid;
BEGIN
  SELECT type INTO nType FROM db.object WHERE id = pId;
  RETURN nType;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectTypeCode --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectTypeCode (
  pId		uuid
) RETURNS	text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT code INTO vCode FROM db.type WHERE id = (
    SELECT type FROM db.object WHERE id = pId
  );

  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectState -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectState (
  pId		uuid
) RETURNS	uuid
AS $$
DECLARE
  nState	uuid;
BEGIN
  SELECT state INTO nState FROM db.object WHERE id = pId;
  RETURN nState;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetObjectOwner -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetObjectOwner (
  pId		uuid,
  pOwner    uuid
) RETURNS 	void
AS $$
BEGIN
  UPDATE db.object SET owner = pOwner WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectOwner -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectOwner (
  pId		uuid
) RETURNS 	uuid
AS $$
DECLARE
  nOwner	uuid;
BEGIN
  SELECT owner INTO nOwner FROM db.object WHERE id = pId;
  RETURN nOwner;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectOper ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectOper (
  pId		uuid
) RETURNS 	uuid
AS $$
DECLARE
  nOper		uuid;
BEGIN
  SELECT oper INTO nOper FROM db.object WHERE id = pId;
  RETURN nOper;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddObjectState -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddObjectState (
  pObject       uuid,
  pState        uuid,
  pDateFrom     timestamp DEFAULT oper_date()
) RETURNS       uuid
AS $$
DECLARE
  nId           uuid;

  dtDateFrom    timestamp;
  dtDateTo      timestamp;
BEGIN
  -- получим дату значения в текущем диапозоне дат
  SELECT id, validFromDate, validToDate INTO nId, dtDateFrom, dtDateTo
    FROM db.object_state
   WHERE object = pObject
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  IF coalesce(dtDateFrom, MINDATE()) = pDateFrom THEN
    -- обновим значение в текущем диапозоне дат
    UPDATE db.object_state SET State = pState
     WHERE object = pObject
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;
  ELSE
    -- обновим дату значения в текущем диапозоне дат
    UPDATE db.object_state SET validToDate = pDateFrom
     WHERE object = pObject
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;

    INSERT INTO db.object_state (object, state, validFromDate, validToDate)
    VALUES (pObject, pState, pDateFrom, coalesce(dtDateTo, MAXDATE()))
    RETURNING id INTO nId;
  END IF;

  UPDATE db.object SET state = pState WHERE id = pObject;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectState -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectState (
  pObject	uuid,
  pDate		timestamp
) RETURNS	uuid
AS $$
DECLARE
  nState	uuid;
BEGIN
  SELECT state INTO nState
    FROM db.object_state
   WHERE object = pObject
     AND validFromDate <= pDate
     AND validToDate > pDate;

  RETURN nState;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectStateCode -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectStateCode (
  pObject	uuid,
  pDate		timestamp DEFAULT oper_date()
) RETURNS 	text
AS $$
DECLARE
  nState	uuid;
  vCode		text;
BEGIN
  vCode := null;

  nState := GetObjectState(pObject, pDate);
  IF nState IS NOT NULL THEN
    SELECT code INTO vCode FROM db.state WHERE id = nState;
  END IF;

  RETURN vCode;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectStateType -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectStateType (
  pObject	uuid,
  pDate		timestamp DEFAULT oper_date()
) RETURNS	uuid
AS $$
DECLARE
  nState	uuid;
BEGIN
  SELECT state INTO nState
    FROM db.object_state
   WHERE object = pObject
     AND validFromDate <= pDate
     AND validToDate > pDate;

  RETURN GetStateTypeByState(nState);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectStateTypeCode ---------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectStateTypeCode (
  pObject	uuid,
  pDate		timestamp DEFAULT oper_date()
) RETURNS 	text
AS $$
DECLARE
  nState	uuid;
BEGIN
  SELECT state INTO nState
    FROM db.object_state
   WHERE object = pObject
     AND validFromDate <= pDate
     AND validToDate > pDate;

  RETURN GetStateTypeCodeByState(nState);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetNewState --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetNewState (
  pMethod	uuid
) RETURNS 	uuid
AS $$
DECLARE
  nNewState	uuid;
BEGIN
  SELECT newstate INTO nNewState FROM db.transition WHERE method = pMethod;
  RETURN nNewState;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PROCEDURE ChangeObjectState -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ChangeObjectState (
  pObject	uuid DEFAULT context_object(),
  pMethod	uuid DEFAULT context_method()
) RETURNS 	void
AS $$
DECLARE
  nNewState	uuid;
  nAction	uuid;
BEGIN
  nNewState := GetNewState(pMethod);
  IF nNewState IS NOT NULL THEN
    PERFORM AddObjectState(pObject, nNewState);
    SELECT action INTO nAction FROM db.method WHERE id = pMethod;
    PERFORM AddMethodStack(jsonb_build_object('object', pObject, 'method', pMethod, 'action', jsonb_build_object('id', nAction, 'code', GetActionCode(nAction)), 'newstate', jsonb_build_object('id', nNewState, 'code', GetStateCode(nNewState))));
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectMethod ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectMethod (
  pObject	uuid,
  pAction	uuid
) RETURNS	uuid
AS $$
DECLARE
  nClass	uuid;
  nState	uuid;
BEGIN
  SELECT class, state INTO nClass, nState FROM db.object WHERE id = pObject;
  RETURN GetMethod(nClass, pAction, nState);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddMethodStack -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddMethodStack (
  pResult   jsonb,
  pObject	uuid DEFAULT context_object(),
  pMethod	uuid DEFAULT context_method()
) RETURNS	void
AS $$
BEGIN
  UPDATE db.method_stack SET result = coalesce(result, '{}'::jsonb) || pResult WHERE object = pObject AND method = pMethod;
  IF NOT FOUND THEN
	INSERT INTO db.method_stack (object, method, result) VALUES (pObject, pMethod, pResult);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION ClearMethodStack ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ClearMethodStack (
  pObject	uuid,
  pMethod	uuid
) RETURNS	void
AS $$
  SELECT AddMethodStack(NULL, pObject, pMethod);
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetMethodStack -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetMethodStack (
  pObject	uuid,
  pMethod	uuid
) RETURNS	jsonb
AS $$
  SELECT result FROM db.method_stack WHERE object = pObject AND method = pMethod
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PROCEDURE ExecuteAction -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ExecuteAction (
  pClass	uuid DEFAULT context_class(),
  pAction	uuid DEFAULT context_action()
) RETURNS	void
AS $$
DECLARE
  nClass	uuid;
  Rec		record;
BEGIN
  FOR Rec IN
    SELECT t.code AS typecode, e.text
      FROM db.event e INNER JOIN db.event_type t ON e.type = t.id
     WHERE e.class = pClass
       AND e.action = pAction
       AND e.enabled
     ORDER BY e.sequence
  LOOP
    IF Rec.typecode = 'parent' THEN
      SELECT parent INTO nClass FROM db.class_tree WHERE id = pClass;
      IF nClass IS NOT NULL THEN
        PERFORM ExecuteAction(nClass, pAction);
      END IF;
    ELSIF Rec.typecode = 'event' THEN
      EXECUTE 'SELECT ' || Rec.Text;
    ELSIF Rec.typecode = 'plpgsql' THEN
      EXECUTE Rec.Text;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PROCEDURE ExecuteMethod -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ExecuteMethod (
  pObject       uuid,
  pMethod       uuid,
  pParams		jsonb DEFAULT null
) RETURNS       jsonb
AS $$
DECLARE
  nSaveObject	uuid;
  nSaveClass	uuid;
  nSaveMethod	uuid;
  nSaveAction	uuid;
  jSaveParams	jsonb;

  sLabel        text;
  sActionCode	text;

  nClass        uuid;
  nAction       uuid;
BEGIN
  IF NOT CheckMethodAccess(pMethod, B'100') THEN
    SELECT label INTO sLabel FROM db.method WHERE id = pMethod;
    PERFORM ExecuteMethodError(sLabel);
  END IF;

  nSaveObject := context_object();
  nSaveClass  := context_class();
  nSaveMethod := context_method();
  nSaveAction := context_action();
  jSaveParams := context_params();

  PERFORM ClearMethodStack(pObject, pMethod);

  nClass := GetObjectClass(pObject);

  SELECT action INTO nAction FROM db.method WHERE id = pMethod;
  SELECT code INTO sActionCode FROM db.action WHERE id = nAction;

  PERFORM InitContext(pObject, nClass, pMethod, nAction);
  PERFORM InitParams(pParams);

  BEGIN
    PERFORM ExecuteAction(nClass, nAction);
  END;

  PERFORM InitParams(jSaveParams);
  PERFORM InitContext(nSaveObject, nSaveClass, nSaveMethod, nSaveAction);

  IF sActionCode <> 'drop' THEN
    PERFORM AddNotification(nClass, nAction, pMethod, pObject);
  END IF;

  RETURN GetMethodStack(pObject, pMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PROCEDURE ExecuteMethodForAllChild ------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ExecuteMethodForAllChild (
  pObject	uuid DEFAULT context_object(),
  pClass	uuid DEFAULT context_class(),
  pMethod	uuid DEFAULT context_method(),
  pAction	uuid DEFAULT context_action(),
  pParams	jsonb DEFAULT context_params()
) RETURNS	jsonb
AS $$
DECLARE
  r			record;
  nMethod	uuid;
  result    jsonb;
BEGIN
  result := jsonb_build_array();

  FOR r IN SELECT id, class, state FROM db.object WHERE parent = pObject AND class = pClass
  LOOP
    nMethod := GetMethod(r.class, pAction, r.state);
    IF nMethod IS NOT NULL THEN
      result := result || ExecuteMethod(r.id, nMethod, pParams);
    END IF;
  END LOOP;

  PERFORM InitContext(pObject, pClass, pMethod, pAction);
  PERFORM InitParams(pParams);

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PROCEDURE ExecuteObjectAction -----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ExecuteObjectAction (
  pObject	uuid,
  pAction	uuid,
  pParams	jsonb DEFAULT null
) RETURNS 	jsonb
AS $$
DECLARE
  nMethod	uuid;
BEGIN
  nMethod := GetObjectMethod(pObject, pAction);

  IF nMethod IS NULL THEN
  	PERFORM MethodActionNotFound(pObject, pAction);
  END IF;

  RETURN ExecuteMethod(pObject, nMethod, pParams);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION IsCreated ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION IsCreated (
  pObject	uuid
) RETURNS 	boolean
AS $$
BEGIN
  RETURN GetObjectStateTypeCode(pObject) = 'created';
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION IsEnabled ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION IsEnabled (
  pObject	uuid
) RETURNS 	boolean
AS $$
BEGIN
  RETURN GetObjectStateTypeCode(pObject) = 'enabled';
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION IsDisabled ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION IsDisabled (
  pObject	uuid
) RETURNS 	boolean
AS $$
BEGIN
  RETURN GetObjectStateTypeCode(pObject) = 'disabled';
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION IsDeleted ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION IsDeleted (
  pObject	uuid
) RETURNS 	boolean
AS $$
BEGIN
  RETURN GetObjectStateTypeCode(pObject) = 'deleted';
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION IsActive -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION IsActive (
  pObject	uuid
) RETURNS 	boolean
AS $$
DECLARE
  vCode		text;
BEGIN
  vCode := GetObjectStateTypeCode(pObject);
  RETURN vCode = 'created' OR vCode = 'enabled';
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoCreate -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DoCreate (
  pObject	uuid
) RETURNS 	jsonb
AS $$
BEGIN
  RETURN ExecuteObjectAction(pObject, GetAction('create'));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoEnable -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DoEnable (
  pObject	uuid
) RETURNS 	jsonb
AS $$
BEGIN
  RETURN ExecuteObjectAction(pObject, GetAction('enable'));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoDisable ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DoDisable (
  pObject	uuid
) RETURNS 	jsonb
AS $$
BEGIN
  RETURN ExecuteObjectAction(pObject, GetAction('disable'));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DoDelete -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DoDelete (
  pObject	uuid
) RETURNS 	jsonb
AS $$
BEGIN
  RETURN ExecuteObjectAction(pObject, GetAction('delete'));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateObjectGroup -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateObjectGroup (
  pCode         text,
  pName         text,
  pDescription  text
) RETURNS       uuid
AS $$
DECLARE
  nId           uuid;
BEGIN
  INSERT INTO db.object_group (code, name, description)
  VALUES (pCode, pName, pDescription)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditObjectGroup -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditObjectGroup (
  pId		    uuid,
  pCode		    text DEFAULT null,
  pName		    text DEFAULT null,
  pDescription	text DEFAULT null
) RETURNS	    void
AS $$
BEGIN
  UPDATE db.object_group
     SET code = coalesce(pCode, code),
         name = coalesce(pName, name),
         description = coalesce(pDescription, description)
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectGroup --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectGroup (
  pCode		text
) RETURNS	uuid
AS $$
DECLARE
  nId		uuid;
BEGIN
  SELECT id INTO nId FROM db.object_group WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ObjectGroup -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ObjectGroup (
  pOwner    uuid DEFAULT current_userid()
) RETURNS	SETOF ObjectGroup
AS $$
  SELECT * FROM ObjectGroup WHERE owner = pOwner
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddObjectToGroup ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddObjectToGroup (
  pGroup	uuid,
  pObject	uuid
) RETURNS	void
AS $$
BEGIN
  INSERT INTO db.object_group_member (gid, object) VALUES (pGroup, pObject)
    ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteObjectFromGroup -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteObjectFromGroup (
  pGroup	uuid,
  pObject	uuid
) RETURNS	void
AS $$
DECLARE
  nCount	integer;
BEGIN
  DELETE FROM db.object_group_member
   WHERE gid = pGroup
     AND object = pObject;

  SELECT count(object) INTO nCount
    FROM db.object_group_member
   WHERE gid = pGroup;

  IF nCount = 0 THEN
    DELETE FROM db.object_group WHERE id = pGroup;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetObjectLink ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает связь с объектом.
 * @param {uuid} pObject - Идентификатор объекта
 * @param {uuid} pLinked - Идентификатор связанного объекта
 * @param {text} pKey - Ключ
 * @param {timestamp} pDateFrom - Дата начала периода
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SetObjectLink (
  pObject       uuid,
  pLinked       uuid,
  pKey          text,
  pDateFrom     timestamp DEFAULT oper_date()
) RETURNS       uuid
AS $$
DECLARE
  nId           uuid;
  nLinked       uuid;

  dtDateFrom    timestamp;
  dtDateTo      timestamp;
BEGIN
  -- получим дату значения в текущем диапозоне дат
  SELECT linked, validFromDate, validToDate INTO nLinked, dtDateFrom, dtDateTo
    FROM db.object_link
   WHERE object = pObject
     AND key = pKey
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  IF nLinked IS DISTINCT FROM pLinked THEN
    -- обновим дату значения в текущем диапозоне дат
    UPDATE db.object_link SET validToDate = pDateFrom
     WHERE object = pObject
       AND key = pKey
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;

    IF pLinked IS NOT NULL THEN
      INSERT INTO db.object_link (object, key, linked, validFromDate, validToDate)
      VALUES (pObject, pKey, pLinked, pDateFrom, coalesce(dtDateTo, MAXDATE()))
      RETURNING id INTO nId;
    END IF;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectLink ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает связанный с объектом объект.
 * @param {uuid} pObject - Идентификатор объекта
 * @param {text} pKey - Ключ
 * @param {timestamp} pDate - Дата
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION GetObjectLink (
  pObject	uuid,
  pKey	    text,
  pDate		timestamp DEFAULT oper_date()
) RETURNS	uuid
AS $$
DECLARE
  nLinked	uuid;
BEGIN
  SELECT linked INTO nLinked
    FROM db.object_link
   WHERE object = pObject
     AND key = pKey
     AND validFromDate <= pDate
     AND validToDate > pDate;

  RETURN nLinked;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewObjectFile ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NewObjectFile (
  pObject	uuid,
  pName		text,
  pPath		text,
  pSize		integer,
  pDate		timestamp,
  pData		bytea DEFAULT null,
  pHash		text DEFAULT null,
  pText		text DEFAULT null,
  pType		text DEFAULT null
) RETURNS	void
AS $$
BEGIN
  INSERT INTO db.object_file (object, file_name, file_path, file_size, file_date, file_data, file_hash, file_text, file_type)
  VALUES (pObject, pName, pPath, pSize, pDate, pData, pHash, pText, pType);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditObjectFile --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditObjectFile (
  pObject   uuid,
  pName		text,
  pPath		text DEFAULT null,
  pSize		integer DEFAULT null,
  pDate		timestamp DEFAULT null,
  pData		bytea DEFAULT null,
  pHash		text DEFAULT null,
  pText		text DEFAULT null,
  pType		text DEFAULT null,
  pLoad		timestamp DEFAULT null
) RETURNS	void
AS $$
BEGIN
  UPDATE db.object_file
    SET file_path = coalesce(pPath, file_path),
        file_size = coalesce(pSize, file_size),
        file_date = coalesce(pDate, file_date),
        file_data = coalesce(pData, file_data),
        file_hash = coalesce(pHash, file_hash),
        file_text = CheckNull(coalesce(pText, file_text, '<null>')),
        file_type = CheckNull(coalesce(pType, file_type, '<null>')),
        load_date = coalesce(pLoad, load_date)
  WHERE object = pObject
    AND file_name = pName
    AND file_path = coalesce(pPath, '~/');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteObjectFile ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteObjectFile (
  pObject   uuid,
  pName		text,
  pPath		text DEFAULT null
) RETURNS	void
AS $$
BEGIN
  DELETE FROM db.object_file WHERE object = pObject AND file_name = pName AND file_path = coalesce(pPath, '~/');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetObjectFile ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetObjectFile (
  pObject	uuid,
  pName		text,
  pPath		text,
  pSize		integer,
  pDate		timestamp,
  pData		bytea DEFAULT null,
  pHash		text DEFAULT null,
  pText		text DEFAULT null,
  pType		text DEFAULT null
) RETURNS	int
AS $$
DECLARE
  Size          int;
BEGIN
  IF coalesce(pSize, 0) >= 0 THEN
    SELECT file_size INTO Size FROM db.object_file WHERE object = pObject AND file_name = pName;
    IF NOT FOUND THEN
      PERFORM NewObjectFile(pObject, pName, pPath, pSize, pDate, pData, pHash, pText, pType);
    ELSE
      PERFORM EditObjectFile(pObject, pName, pPath, pSize, pDate, pData, pHash, pText, pType);
    END IF;
  ELSE
    PERFORM DeleteObjectFile(pObject, pName);
  END IF;
  RETURN Size;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectFiles --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectFiles (
  pObject	uuid
) RETURNS	text[][]
AS $$
DECLARE
  arResult	text[][];
  i		    integer DEFAULT 1;
  r		    ObjectFile%rowtype;
BEGIN
  FOR r IN
    SELECT *
      FROM ObjectFile
     WHERE object = pObject
  LOOP
    arResult[i] := ARRAY[r.object, r.name, r.path, r.size, r.date, r.hash, r.text, r.type, r.loaded];
    i := i + 1;
  END LOOP;

  RETURN arResult;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectFilesJson ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectFilesJson (
  pObject	uuid
) RETURNS	json
AS $$
DECLARE
  arResult	json[];
  r		    record;
BEGIN
  FOR r IN
    SELECT Object, Name, Path, Size, Date, Hash, Text, Type, Loaded
      FROM ObjectFile
     WHERE object = pObject
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectFilesJsonb ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectFilesJsonb (
  pObject	uuid
) RETURNS	jsonb
AS $$
BEGIN
  RETURN GetObjectFilesJson(pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewObjectData ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NewObjectData (
  pObject	uuid,
  pType		text,
  pCode		text,
  pData		text
) RETURNS	void
AS $$
BEGIN
  INSERT INTO db.object_data (object, type, code, data)
  VALUES (pObject, pType, pCode, pData);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditObjectData --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditObjectData (
  pObject	uuid,
  pType		text,
  pCode		text,
  pData		text
) RETURNS	void
AS $$
BEGIN
  UPDATE db.object_data
     SET data = coalesce(pData, data)
   WHERE object = pObject
     AND type = pType
     AND code = pCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteObjectData ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteObjectData (
  pObject	uuid,
  pType		text,
  pCode		text
) RETURNS	void
AS $$
BEGIN
  DELETE FROM db.object_data WHERE object = pObject AND type = pType AND code = pCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetObjectData ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetObjectData (
  pObject	uuid,
  pType		text,
  pCode		text,
  pData		text
) RETURNS	text
AS $$
DECLARE
  vData		text;
BEGIN
  IF pData IS NOT NULL THEN
    SELECT data INTO vData FROM db.object_data WHERE object = pObject AND type = pType AND code = pCode;
    IF NOT FOUND THEN
      PERFORM NewObjectData(pObject, pType, pCode, pData);
    ELSE
      PERFORM EditObjectData(pObject, pType, pCode, pData);
    END IF;
  ELSE
    PERFORM DeleteObjectData(pObject, pType, pCode);
  END IF;
  RETURN vData;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetObjectDataJSON -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetObjectDataJSON (
  pObject	uuid,
  pCode		text,
  pData		json
) RETURNS	void
AS $$
BEGIN
  PERFORM SetObjectData(pObject, 'json', pCode, pData::text);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetObjectDataXML ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetObjectDataXML (
  pObject	uuid,
  pCode		text,
  pData		xml
) RETURNS	void
AS $$
BEGIN
  PERFORM SetObjectData(pObject, 'xml', pCode, pData::text);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectData ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectData (
  pObject	uuid,
  pType		text,
  pCode		text
) RETURNS	text
AS $$
DECLARE
  vData		text;
BEGIN
  SELECT data INTO vData FROM db.object_data WHERE object = pObject AND type = pType AND code = pCode;
  RETURN vData;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectDataJSON -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectDataJSON (
  pObject	uuid,
  pCode		text
) RETURNS	json
AS $$
BEGIN
  RETURN GetObjectData(pObject, 'json', pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectDataXML ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectDataXML (
  pObject	uuid,
  pCode		text
) RETURNS	json
AS $$
BEGIN
  RETURN GetObjectData(pObject, 'xml', pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectDataJson -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectDataJson (
  pObject	uuid
) RETURNS	json
AS $$
DECLARE
  r			record;
  arResult	json[];
BEGIN
  FOR r IN
    SELECT object, type, Code, Data
      FROM ObjectData
     WHERE object = pObject
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectDataJsonb ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectDataJsonb (
  pObject	uuid
) RETURNS	jsonb
AS $$
BEGIN
  RETURN GetObjectDataJson(pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ObjectCoordinates -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ObjectCoordinates (
  pDateFrom     timestamptz,
  pUserId		uuid DEFAULT current_userid()
) RETURNS       SETOF ObjectCoordinates
AS $$
  WITH access AS (
	WITH member_group AS (
		SELECT pUserId AS userid UNION SELECT userid FROM db.member_group WHERE member = pUserId
	)
	SELECT a.object, bit_or(a.mask) AS mask
	  FROM db.object_coordinates oc INNER JOIN db.aou       a ON oc.object = a.object
							        INNER JOIN member_group m ON a.userid = m.userid
     WHERE oc.validfromdate <= pDateFrom
	   AND oc.validtodate > pDateFrom
	 GROUP BY a.object
  )
  SELECT oc.* FROM ObjectCoordinates oc INNER JOIN access a ON oc.object = a.object AND a.mask & B'100' = B'100'
   WHERE oc.validfromdate <= pDateFrom
	 AND oc.validtodate > pDateFrom
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewObjectCoordinates --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NewObjectCoordinates (
  pObject		uuid,
  pCode			text,
  pLatitude		numeric,
  pLongitude	numeric,
  pAccuracy		numeric DEFAULT 0,
  pLabel		text DEFAULT null,
  pDescription	text DEFAULT null,
  pData			jsonb DEFAULT null,
  pDateFrom		timestamptz DEFAULT Now()
) RETURNS		uuid
AS $$
DECLARE
  nId			uuid;
  dtDateFrom	timestamptz;
  dtDateTo		timestamptz;
BEGIN
  -- получим дату значения в текущем диапозоне дат
  SELECT id, validFromDate, validToDate INTO nId, dtDateFrom, dtDateTo
    FROM db.object_coordinates
   WHERE object = pObject
     AND code = pCode
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  IF coalesce(dtDateFrom, MINDATE()) = pDateFrom THEN
    -- обновим значение в текущем диапозоне дат
    UPDATE db.object_coordinates
       SET latitude = pLatitude, longitude = pLongitude, accuracy = pAccuracy,
           label = coalesce(pLabel, label),
           description = coalesce(pDescription, description)
     WHERE object = pObject
       AND code = pCode
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;
  ELSE
    -- обновим дату значения в текущем диапозоне дат
    UPDATE db.object_coordinates SET validToDate = pDateFrom
     WHERE object = pObject
       AND code = pCode
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;

    INSERT INTO db.object_coordinates (object, code, latitude, longitude, accuracy, label, description, data, validFromDate, validToDate)
    VALUES (pObject, pCode, pLatitude, pLongitude, pAccuracy, pLabel, pDescription, pData, pDateFrom, coalesce(dtDateTo, MAXDATE()))
    RETURNING id INTO nId;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteObjectCoordinates -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteObjectCoordinates (
  pObject	uuid,
  pCode		text
) RETURNS	void
AS $$
BEGIN
  DELETE FROM db.object_coordinates WHERE object = pObject AND code = pCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectCoordinates --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectCoordinates (
  pObject       uuid,
  pCode         text
) RETURNS       ObjectCoordinates
AS $$
  SELECT * FROM ObjectCoordinates WHERE object = pObject AND code = pCode;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectCoordinatesJson ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectCoordinatesJson (
  pObject		uuid,
  pCode			text DEFAULT NULL,
  pDateFrom		timestamptz DEFAULT Now()
) RETURNS		json
AS $$
DECLARE
  arResult		json[];
  r             record;
BEGIN
  FOR r IN
    SELECT *
      FROM ObjectCoordinates
     WHERE object = pObject
       AND code = coalesce(pCode, code)
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectCoordinatesJsonb ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectCoordinatesJsonb (
  pObject	uuid
) RETURNS	jsonb
AS $$
BEGIN
  RETURN GetObjectCoordinatesJson(pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;