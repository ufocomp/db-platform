--------------------------------------------------------------------------------
-- DOCUMENT --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.get_document ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает документ.
 * @param {numeric} pId - Идентификатор документа
 * @return {VDocument} - Документ
 */
CREATE OR REPLACE FUNCTION api.get_document (
  pId                numeric
) RETURNS        SETOF Document
AS $$
  SELECT * FROM Document WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
