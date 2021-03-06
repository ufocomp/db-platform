--------------------------------------------------------------------------------
-- FUNCTION GetLocale ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetLocale (
  pCode		text
) RETURNS	uuid
AS $$
DECLARE
  uId		uuid;
BEGIN
  SELECT id INTO uId FROM db.locale WHERE code = pCode;
  RETURN uId;
END;
$$ LANGUAGE plpgsql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetLocaleCode ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetLocaleCode (
  pId		uuid
) RETURNS	text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT code INTO vCode FROM db.locale WHERE id = pId;
  return vCode;
END;
$$ LANGUAGE plpgsql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
