--------------------------------------------------------------------------------
-- NOTIFICATION ----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.notification -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.notification (
    id			bigserial PRIMARY KEY,
    object		numeric(12) NOT NULL,
    class		numeric(12) NOT NULL,
    method		numeric(12) NOT NULL,
    action		numeric(12) NOT NULL,
    userid      numeric(12) NOT NULL,
    datetime    timestamp NOT NULL DEFAULT Now(),
    CONSTRAINT fk_notification_object FOREIGN KEY (object) REFERENCES db.object(id),
    CONSTRAINT fk_notification_class FOREIGN KEY (class) REFERENCES db.class_tree(id),
    CONSTRAINT fk_notification_method FOREIGN KEY (method) REFERENCES db.method(id),
    CONSTRAINT fk_notification_action FOREIGN KEY (action) REFERENCES db.action(id),
    CONSTRAINT fk_notification_userid FOREIGN KEY (userid) REFERENCES db.user(id)
);

COMMENT ON TABLE db.notification IS 'Уведомления.';

COMMENT ON COLUMN db.notification.id IS 'Идентификатор';
COMMENT ON COLUMN db.notification.object IS 'Объект';
COMMENT ON COLUMN db.notification.class IS 'Класс';
COMMENT ON COLUMN db.notification.method IS 'Метод';
COMMENT ON COLUMN db.notification.action IS 'Действие';
COMMENT ON COLUMN db.notification.userid IS 'Учётная запись пользователя';
COMMENT ON COLUMN db.notification.datetime IS 'Дата и время';

CREATE INDEX ON db.notification (object);
CREATE INDEX ON db.notification (class);
CREATE INDEX ON db.notification (method);
CREATE INDEX ON db.notification (action);
CREATE INDEX ON db.notification (userid);
CREATE INDEX ON db.notification (datetime);

--------------------------------------------------------------------------------
-- VIEW Notification -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Notification (Id, DateTime, UserId, Object,
  Class, ClassCode, Action, ActionCode, Method, MethodCode
)
AS
  SELECT n.id, n.datetime, n.userid, n.object,
         n.class, c.code, n.action, a.code, n.method, m.code
    FROM db.notification n INNER JOIN db.class_tree c ON n.class = c.id
                     INNER JOIN db.action     a ON n.action = a.id
                     INNER JOIN db.method     m ON n.method = m.id;

GRANT SELECT ON Notification TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION AddNotification ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddNotification (
  pObject	numeric,
  pClass	numeric,
  pMethod   numeric,
  pAction	numeric,
  pUserId	numeric DEFAULT current_userid(),
  pDateTime timestamp DEFAULT Now()
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  INSERT INTO db.notification (object, class, method, action, userid, datetime)
  VALUES (pObject, pClass, pMethod, pAction, pUserId, pDateTime)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditNotification ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditNotification (
  pId       numeric,
  pObject	numeric DEFAULT null,
  pClass	numeric DEFAULT null,
  pMethod   numeric DEFAULT null,
  pAction	numeric DEFAULT null,
  pUserId	numeric DEFAULT null,
  pDateTime timestamp DEFAULT null
) RETURNS	void
AS $$
BEGIN
  UPDATE db.notification
     SET object = coalesce(pObject, object),
         class = coalesce(pClass, class),
         method = coalesce(pMethod, method),
         action = coalesce(pAction, action),
         userid = coalesce(pUserId, userid),
         datetime = coalesce(pDateTime, datetime)
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteNotification -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteNotification (
  pId		numeric
) RETURNS 	void
AS $$
BEGIN
  DELETE FROM db.notification WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;