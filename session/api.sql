--------------------------------------------------------------------------------
-- SESSION ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.set_session_area --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает зону.
 * @param {numeric} pArea - Идентификатор зоны
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.set_session_area (
  pArea     numeric
) RETURNS   void
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.area WHERE id = pArea;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('зона', 'id', pArea);
  END IF;

  PERFORM SetArea(pArea);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_session_area --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает зону.
 * @param {text} pArea - Код зоны
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.set_session_area (
  pArea     text
) RETURNS   void
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.area WHERE code = pArea;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('зона', 'code', pArea);
  END IF;

  PERFORM SetArea(nId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_session_interface ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает интерфейс.
 * @param {numeric} pInterface - Идентификатор интерфейса
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.set_session_interface (
  pInterface	numeric
) RETURNS       void
AS $$
DECLARE
  nId			numeric;
BEGIN
  SELECT id INTO nId FROM db.interface WHERE id = pInterface;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('интерфейс', 'id', pInterface);
  END IF;

  PERFORM SetInterface(pInterface);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_session_interface ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает интерфейс.
 * @param {numeric} pInterface - Идентификатор интерфейса
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.set_session_interface (
  pInterface	text
) RETURNS       void
AS $$
DECLARE
  nId			numeric;
BEGIN
  SELECT id INTO nId FROM db.interface WHERE sid = pInterface;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('интерфейс', 'sid', pInterface);
  END IF;

  PERFORM SetInterface(nId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_session_oper_date ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает дату операционного дня.
 * @param {timestamp} pOperDate - Дата операционного дня
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.set_session_oper_date (
  pOperDate 	timestamp
) RETURNS       void
AS $$
BEGIN
  PERFORM SetOperDate(pOperDate);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_session_oper_date ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает дату операционного дня.
 * @param {timestamptz} pOperDate - Дата операционного дня
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.set_session_oper_date (
  pOperDate   timestamptz
) RETURNS     void
AS $$
BEGIN
  PERFORM SetOperDate(pOperDate);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_session_locale ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает по идентификатору текущий язык.
 * @param {numeric} pLocale - Идентификатор языка
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.set_session_locale (
  pLocale     numeric
) RETURNS     void
AS $$
DECLARE
  nId         numeric;
BEGIN
  SELECT id INTO nId FROM db.locale WHERE id = pLocale;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('язык', 'id', pLocale);
  END IF;

  PERFORM SetLocale(pLocale);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_session_locale ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает по идентификатору текущий язык.
 * @param {text} pCode - Код языка
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.set_session_locale (
  pCode     text DEFAULT 'ru'
) RETURNS   void
AS $$
DECLARE
  arCodes   text[];
  r         record;
BEGIN
  FOR r IN SELECT code FROM db.locale
  LOOP
    arCodes := array_append(arCodes, r.code);
  END LOOP;

  IF array_position(arCodes, pCode) IS NULL THEN
    PERFORM IncorrectCode(pCode, arCodes);
  END IF;

  PERFORM SetLocale(GetLocale(pCode));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
