--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddCalendarEvents -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddCalendarEvents (
  pClass        numeric
)
RETURNS         void
AS $$
DECLARE
  r             record;

  nParent       numeric;
  nEvent        numeric;
BEGIN
  nParent := GetEventType('parent');
  nEvent := GetEventType('event');

  FOR r IN SELECT * FROM Action
  LOOP

    IF r.code = 'create' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Календарь создан', 'EventCalendarCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Календарь открыт', 'EventCalendarOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Календарь изменён', 'EventCalendarEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Календарь сохранён', 'EventCalendarSave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Календарь доступен', 'EventCalendarEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Календарь недоступен', 'EventCalendarDisable();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Календарь будет удалён', 'EventCalendarDelete();');
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Календарь восстановлен', 'EventCalendarRestore();');
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Календарь будет уничтожен', 'EventCalendarDrop();');
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
    END IF;

  END LOOP;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassCalendar ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassCalendar (
  pParent       numeric,
  pEntity       numeric
)
RETURNS         numeric
AS $$
DECLARE
  nClass        numeric;
BEGIN
  -- Класс
  nClass := AddClass(pParent, pEntity, 'calendar', 'Календарь', false);

  -- Тип
  PERFORM AddType(nClass, 'workday.calendar', 'Рабочий', 'Календарь рабочих дней.');

  -- Событие
  PERFORM AddCalendarEvents(nClass);

  -- Метод
  PERFORM AddDefaultMethods(nClass);

  RETURN nClass;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateEntityCalendar --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateEntityCalendar (
  pParent       numeric
)
RETURNS         numeric
AS $$
DECLARE
  nEntity       numeric;
BEGIN
  -- Сущность
  nEntity := AddEntity('calendar', 'Календарь');

  -- Класс
  PERFORM CreateClassCalendar(pParent, nEntity);

  RETURN nEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;