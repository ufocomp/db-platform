--------------------------------------------------------------------------------
-- Locale ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Locale
as
  SELECT * FROM db.locale;

GRANT SELECT ON Locale TO administrator;
