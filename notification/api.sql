--------------------------------------------------------------------------------
-- NOTIFICATION ----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.notification ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.notification
AS
  SELECT * FROM Notification;

GRANT SELECT ON api.notification TO administrator;

--------------------------------------------------------------------------------
-- api.notification ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.notification (
  pDateFrom     timestamp
) RETURNS       SETOF api.notification
AS $$
  SELECT * FROM api.notification WHERE datetime >= pDateFrom ORDER BY id;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_notification --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает уведомление.
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.get_notification (
  pId           numeric
) RETURNS       SETOF api.notification
AS $$
  SELECT * FROM api.notification WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_notification -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает уведомления в виде списка.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.object_group}
 */
CREATE OR REPLACE FUNCTION api.list_notification (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.object_group
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'notification', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;