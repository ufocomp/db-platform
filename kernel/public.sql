--------------------------------------------------------------------------------
-- ALL_TAB_COLUMNS -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW all_tab_columns(table_name, column_id, column_name, data_type, udt_name)
AS
  SELECT table_name, ordinal_position as column_id, column_name, data_type, udt_name
    FROM information_schema.columns
   WHERE table_schema = 'kernel';

GRANT SELECT ON all_tab_columns TO PUBLIC;

--------------------------------------------------------------------------------
-- ALL_COL_COMMENTS ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW all_col_comments(table_name, table_description, column_name, column_description)
AS
  SELECT table_name, 
         obj_description(format('%s.%s', isc.table_schema, isc.table_name)::regclass::oid, 'pg_class') as table_description,
         column_name,
         pg_catalog.col_description(format('%s.%s', isc.table_schema, isc.table_name)::regclass::oid, isc.ordinal_position) as column_description
    FROM information_schema.columns isc
   WHERE table_schema = 'kernel';

GRANT SELECT ON all_col_comments TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION array_pos ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION array_pos (
  anyarray	    text[],
  anyelement 	text
) RETURNS	    int
AS $$
DECLARE
  i		        int;
  l		        int;
BEGIN
  i := 1;
  l := array_length(anyarray, 1);
  WHILE (i <= l) AND (anyarray[i] <> anyelement) LOOP
    i := i + 1;
  END LOOP;

  IF i > l THEN
    i := 0;
  END IF;

  RETURN i;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- FUNCTION array_pos ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION array_pos (
  anyarray	    numeric[],
  anyelement 	numeric
) RETURNS	    int
AS $$
DECLARE
  i		        int;
  l		        int;
BEGIN
  i := 1;
  l := array_length(anyarray, 1);
  WHILE (i <= l) AND (anyarray[i] <> anyelement) LOOP
    i := i + 1;
  END LOOP;

  IF i > l THEN
    i := 0;
  END IF;

  RETURN i;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- FUNCTION string_to_array_trim -----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION string_to_array_trim (
  str		text,
  sep	 	text
) RETURNS	text[]
AS $$
DECLARE
  i		    int;
  pos		int;
  arr		text[];
BEGIN
  pos := StrPos(str, sep);
  i := 1;

  WHILE pos > 0
  LOOP
    arr[i] := trim(SubStr(str, 1, pos - 1));
    str := trim(SubStr(str, pos + 1));
    pos := StrPos(str, sep);
    i := i + 1;
  END LOOP;

  arr[i] := str;

  RETURN arr;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- FUNCTION str_to_inet --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION str_to_inet (
  str		text,
  OUT host	inet,
  OUT range integer
) RETURNS	record
AS $$
DECLARE
  vHost		text;
  vStr		text;

  pos		int;
  nMask		int;
BEGIN
  range := null;
  nMask := 32;

  vStr := str;
  pos := StrPos(vStr, '-');

  IF pos > 0 THEN
    vHost := SubStr(vStr, 1, pos - 1);
    vStr := SubStr(vStr, pos + 1);
    range := (vStr::inet - vHost::inet) + 1;
  ELSE
    vHost := vStr;
  END IF;

  vStr := vHost;
  pos := StrPos(vStr, '*');

  WHILE pos > 0
  LOOP
    nMask := nMask - 8;
    vStr := SubStr(vStr, pos + 1);
    pos := StrPos(vStr, '*');
  END LOOP;

  host := replace(vHost, '*', '0') || '/' || nMask;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- FUNCTION IntToStr -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION IntToStr (
  pValue	numeric,
  pFormat	text DEFAULT 'FM999999999990'
) RETURNS	text
AS $$
BEGIN
  RETURN to_char(pValue, pFormat);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION IntToStr(numeric, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION StrToInt -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION StrToInt (
  pValue	text,
  pFormat	text DEFAULT '999999999999'
) RETURNS	numeric
AS $$
BEGIN
  RETURN to_number(pValue, pFormat);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION IntToStr(numeric, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION DateToStr ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DateToStr (
  pValue	timestamptz,
  pFormat	text DEFAULT 'DD.MM.YYYY HH24:MI:SS'
) RETURNS	text
AS $$
BEGIN
  RETURN to_char(pValue, pFormat);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION DateToStr(timestamptz, text) TO PUBLIC;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DateToStr (
  pValue	timestamp,
  pFormat	text DEFAULT 'DD.MM.YYYY HH24:MI:SS'
) RETURNS	text
AS $$
BEGIN
  RETURN to_char(pValue, pFormat);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION DateToStr(timestamp, text) TO PUBLIC;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DateToStr (
  pValue	date,
  pFormat	text DEFAULT 'DD.MM.YYYY'
) RETURNS	text
AS $$
BEGIN
  RETURN to_char(pValue, pFormat);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION DateToStr(date, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION StrToDate ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION StrToDate (
  pValue	text,
  pFormat	text DEFAULT 'DD.MM.YYYY'
) RETURNS	date
AS $$
BEGIN
  RETURN to_date(pValue, pFormat);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION StrToDate(text, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION StrToTimeStamp -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION StrToTimeStamp (
  pValue	text,
  pFormat	text DEFAULT 'DD.MM.YYYY HH24:MI:SS'
) RETURNS	timestamp
AS $$
BEGIN
  RETURN to_timestamp(pValue, pFormat);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION StrToTimeStamp(text, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION StrToTimeStamptz ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION StrToTimeStamptz (
  pValue	text,
  pFormat	text DEFAULT 'DD.MM.YYYY HH24:MI:SS'
) RETURNS	timestamptz
AS $$
BEGIN
  RETURN to_timestamp(pValue, pFormat);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION StrToTimeStamptz(text, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION MINDATE ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION MINDATE() RETURNS DATE
AS $$
BEGIN
  RETURN TO_DATE('2000-01-01', 'YYYY-MM-DD');
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION MINDATE() TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION MAXDATE ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION MAXDATE() RETURNS DATE
AS $$
BEGIN
  RETURN TO_DATE('4433-12-31', 'YYYY-MM-DD');
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION MAXDATE() TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckNull (
  pValue	text
) RETURNS	text
AS $$
BEGIN
  RETURN NULLIF(pValue, '<null>');
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION CheckNull(text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckNull (
  pValue	json
) RETURNS	json
AS $$
BEGIN
  RETURN NULLIF(pValue, '{}'::json);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION CheckNull(json) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckNull (
  pValue	jsonb
) RETURNS	jsonb
AS $$
BEGIN
  RETURN NULLIF(pValue, '{}'::jsonb);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION CheckNull(jsonb) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckNull (
  pValue	numeric
) RETURNS	numeric
AS $$
BEGIN
  RETURN NULLIF(pValue, 0);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION CheckNull(numeric) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckNull (
  pValue	integer
) RETURNS	integer
AS $$
BEGIN
  RETURN NULLIF(pValue, -1);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION CheckNull(integer) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION CheckNull ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckNull (
  pValue	timestamp
) RETURNS	timestamp
AS $$
BEGIN
  RETURN NULLIF(pValue, MINDATE());
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION CheckNull(timestamp) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION GetCompare ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetCompare (
  pCompare	text
) RETURNS	text
AS $$
BEGIN
  CASE pCompare
  WHEN 'EQL' THEN
    RETURN ' = ';
  WHEN 'NEQ' THEN
    RETURN ' <> ';
  WHEN 'LSS' THEN
    RETURN ' < ';
  WHEN 'LEQ' THEN
    RETURN ' <= ';
  WHEN 'GTR' THEN
    RETURN ' > ';
  WHEN 'GEQ' THEN
    RETURN ' >= ';
  WHEN 'GIN' THEN
    RETURN ' @> ';
  WHEN 'AND' THEN
    RETURN ' & ';
  WHEN 'OR' THEN
    RETURN ' | ';
  WHEN 'XOR' THEN
    RETURN ' # ';
  WHEN 'NOT' THEN
    RETURN ' ~ ';
  WHEN 'ISN' THEN
    RETURN ' IS ';
  WHEN 'INN' THEN
    RETURN ' IS NOT ';
  WHEN 'LKE' THEN
    RETURN ' LIKE ';
  WHEN 'IKE' THEN
    RETURN ' ILIKE ';
  WHEN 'SIM' THEN
    RETURN ' SIMILAR TO ';
  WHEN 'PSX' THEN
    RETURN ' ~ ';
  WHEN 'PSI' THEN
    RETURN ' ~* ';
  WHEN 'PSN' THEN
    RETURN ' !~ ';
  WHEN 'PIN' THEN
    RETURN ' !~* ';
  ELSE
    NULL;
  END CASE;

  RETURN ' = ';
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION GetCompare(text) TO PUBLIC;

--------------------------------------------------------------------------------
-- GetColumns ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetColumns (
  pTable	text,
  pSchema	text DEFAULT current_schema(),
  pAlias	text DEFAULT null
) RETURNS	text[]
AS $$
DECLARE
  arResult	text[];
  r		record;
BEGIN
  FOR r IN
    SELECT column_name
      FROM information_schema.columns
     WHERE table_schema = lower(pSchema)
       AND table_name = lower(pTable)
     ORDER BY ordinal_position
  LOOP
    arResult := array_append(arResult, coalesce(pAlias || '.', '') || r.column_name::text);
  END LOOP;

  RETURN arResult;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

GRANT EXECUTE ON FUNCTION GetColumns(text, text, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- GetRoutines -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetRoutines (
  pRoutine      text,
  pSchema	    text DEFAULT current_schema(),
  pDataType 	boolean DEFAULT false,
  pAlias	    text DEFAULT null,
  pNameFrom     int DEFAULT 2
) RETURNS	    text[]
AS $$
DECLARE
  r             record;
  arResult      text[];
BEGIN
  FOR r IN
    SELECT ip.ordinal_position, ip.parameter_name, ip.data_type
      FROM information_schema.routines ir INNER JOIN information_schema.parameters ip ON ip.specific_name = ir.specific_name
     WHERE ir.specific_schema = pSchema
       AND ir.routine_name = pRoutine
       AND ip.parameter_mode = 'IN'
     ORDER BY ordinal_position
  LOOP
    IF pDataType THEN
      arResult := array_append(arResult, SubStr(r.parameter_name::text, pNameFrom) || ' ' || r.data_type::text);
    ELSE
      arResult := array_append(arResult, coalesce(pAlias || '.', '') || SubStr(r.parameter_name::text, pNameFrom));
    END IF;
  END LOOP;

  RETURN arResult;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

GRANT EXECUTE ON FUNCTION GetRoutines(text, text, boolean, text, int) TO PUBLIC;

--------------------------------------------------------------------------------
-- array_add_text --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION array_add_text (
  pArray	text[],
  pText		text
) RETURNS	text[]
AS $$
DECLARE
  i		    integer;
  arResult	text[];
BEGIN
  FOR i IN 1..array_length(pArray, 1)
  LOOP
    arResult := array_append(arResult, pArray[i] || pText);
  END LOOP;

  RETURN arResult;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

GRANT EXECUTE ON FUNCTION array_add_text(text[], text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION min_array ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION min_array (
  parray	anyarray,
  pelement 	anyelement DEFAULT null
) RETURNS	anyelement
AS $$
DECLARE
  i		integer;
  r		integer;
BEGIN
  i := 1;
  r := null;
  FOR i IN 1..array_length(parray, 1) 
  LOOP
    IF pelement IS NOT NULL THEN
      IF coalesce(r, pelement) = pelement THEN
        r = parray[i];
      ELSE
        IF parray[i] <> pelement THEN
          r = least(coalesce(r, parray[i]), parray[i]);
        END IF;
      END IF;
    ELSE
      r = least(coalesce(r, parray[i]), parray[i]);
    END IF;
  END LOOP;

  RETURN r;
EXCEPTION
WHEN others THEN
  RETURN null;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION min_array(anyarray, anyelement) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION max_array ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION max_array (
  parray	anyarray,
  pelement 	anyelement DEFAULT null
) RETURNS	anyelement
AS $$
DECLARE
  i		    integer;
  r		    integer;
BEGIN
  i := 1;
  r := null;
  FOR i IN 1..array_length(parray, 1) 
  LOOP
    IF pelement IS NOT NULL THEN
      IF coalesce(r, pelement) = pelement THEN
        r = parray[i];
      ELSE
        IF parray[i] <> pelement THEN
          r = greatest(coalesce(r, parray[i]), parray[i]);
        END IF;
      END IF;
    ELSE
      r = greatest(coalesce(r, parray[i]), parray[i]);
    END IF;
  END LOOP;

  RETURN r;
EXCEPTION
WHEN others THEN
  RETURN null;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION max_array(anyarray, anyelement) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION inet_to_array ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION inet_to_array (
  ip		inet
) RETURNS	text[]
AS $$
DECLARE
  r		    text[];
  i		    integer;
  p		    integer;
  v		    text;
BEGIN
  v := host(ip);
  p := position('.' in v);
  i := 0;

  WHILE p > 0
  LOOP
    r[i] := SubString(v FROM 1 FOR p - 1);
    v := SubString(v FROM p + 1);
    p := position('.' in v);
    i := i + 1;
  END LOOP;

  r[i] := v;

  RETURN r;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION inet_to_array(inet) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION UTC ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION UTC()
RETURNS 	timestamptz
AS $$
BEGIN
  RETURN current_timestamp at time zone 'utc';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION UTC() TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION GetISOTime ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetISOTime (
  pTime		timestamp DEFAULT current_timestamp at time zone 'utc'
)
RETURNS 	text
AS $$
BEGIN
  RETURN replace(to_char(pTime, 'YYYY-MM-DD#HH24:MI:SS.MSZ'), '#', 'T');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION GetISOTime(timestamp) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION GetEpoch -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetEpoch (
  pTime		timestamp DEFAULT current_timestamp at time zone 'utc'
)
RETURNS 	double precision
AS $$
BEGIN
  RETURN trunc(extract(EPOCH FROM pTime));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION GetEpoch(timestamp) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION GetEpochMs ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetEpochMs (
  pTime		timestamp DEFAULT current_timestamp at time zone 'utc'
)
RETURNS 	double precision
AS $$
BEGIN
  RETURN trunc(extract(EPOCH FROM pTime) * 1000);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION GetEpochMs(timestamp) TO PUBLIC;

--------------------------------------------------------------------------------
-- quote_literal_json ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION quote_literal_json (
  pStr		text
) RETURNS	text
AS $$
DECLARE
  l		    integer;
  c		    integer;
BEGIN
  l := position('->>' in pStr);
  IF l > 0 THEN
    c := position(')' in SubStr(pStr, l + 3));
    IF position(E'\'' in pStr) = 0 THEN
      IF c > 0 THEN
        pStr := SubStr(pStr, 1, l + 2) || quote_literal(SubStr(pStr, l + 3, c - 1)) || ')';
      ELSE
        pStr := SubStr(pStr, 1, l + 2) || quote_literal(SubStr(pStr, l + 3));
      END IF;
    END IF;
  END IF;
  RETURN pStr;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION quote_literal_json(text) TO PUBLIC;

--------------------------------------------------------------------------------
-- array_quote_literal_json ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION array_quote_literal_json (
  pArray	anyarray
) RETURNS	anyarray
AS $$
DECLARE
  i		    integer;
  l		    integer;
  vStr		text;
BEGIN
  FOR i IN 1..array_length(pArray, 1)
  LOOP
    vStr := pArray[i];
    l := position('->>' in vStr);
    IF l > 0 THEN
      IF position(E'\'' in vStr) = 0 THEN
        pArray[i] := SubString(vStr FROM 1 FOR l + 2) || quote_literal(SubString(vStr FROM l + 3));
      END IF;
    END IF;
  END LOOP;

  RETURN pArray;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION array_quote_literal_json(anyarray) TO PUBLIC;

--------------------------------------------------------------------------------
-- find_value_in_array ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION find_value_in_array (
  pArray	anyarray,
  pKey      text
) RETURNS	text
AS $$
DECLARE
  i		    integer;
  pairs     text[];
BEGIN
  FOR i IN 1..array_length(pArray, 1)
  LOOP
    pairs := string_to_array(pArray[i], '=');
    IF pairs[1] = pKey THEN
      RETURN pairs[2];
    END IF;
  END LOOP;

  RETURN null;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION find_value_in_array(anyarray, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION result_success -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION result_success (
  result	out boolean,
  message	out text
)
RETURNS 	record
AS $$
BEGIN
  result := true;
  message := 'Успешно.';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION result_success() TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION random_between -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION random_between (
  low     int,
  high    int
) RETURNS int
AS
$$
BEGIN
  RETURN floor(random() * (high - low + 1)) + low;
END;
$$ LANGUAGE plpgsql VOLATILE;

GRANT EXECUTE ON FUNCTION random_between(int, int) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION hex_to_int ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION hex_to_int (
  hex			text
) RETURNS		SETOF bigint
AS
$$
BEGIN
  RETURN QUERY EXECUTE 'SELECT x' || quote_literal(hex) || '::bigint';
END
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION hex_to_int(text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION dec_to_bin ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION dec_to_bin (
  D			numeric,
  L			integer DEFAULT 1,
  F			text DEFAULT '0'
) RETURNS 	text
AS
$$
DECLARE
  A 		text[];
  S 		text;
  N 		numeric;
  I 		integer;
BEGIN
  N := D;
  I := 0;
  S := '';

  WHILE N > 0
  LOOP
	A[I] := to_char(mod(N, 2), 'FM0');
	S := A[I] || S;
	N := floor(N / 2);
	I := I + 1;
  END LOOP;

  RETURN lpad(S, greatest(length(S), L), F);
END
$$ LANGUAGE plpgsql IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION bin_to_dec ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION bin_to_dec (
  B			text
) RETURNS 	numeric
AS
$$
DECLARE
  N			numeric;
  L 		integer;
  I			integer;
BEGIN
  N := 0;
  L := length(B);

  FOR I IN 0 .. L - 1
  LOOP
	N := (to_number(SubStr(B, L - I, 1), '0') * power(2, I)) + N;
  END LOOP;

  RETURN N;
END
$$ LANGUAGE plpgsql IMMUTABLE;

--------------------------------------------------------------------------------
-- FUNCTION bin_to_dec ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION bit_copy (
  B 		numeric,
  P 		integer,
  C 		integer
) RETURNS 	numeric
AS
$$
DECLARE
  S 		text;
BEGIN
  IF B >= 0 THEN
	S := dec_to_bin(B, 64, '0');
  ELSE
	S := dec_to_bin(B, 64, '1');
  END IF;

  RETURN bin_to_dec(SubStr(S, length(S) - (P + C - 1), C));
END
$$ LANGUAGE plpgsql IMMUTABLE;

--------------------------------------------------------------------------------
-- IEEE754_32 ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION IEEE754_32 (
  P			numeric
) RETURNS 	numeric
AS
$$
DECLARE
  F   		numeric;
  S   		numeric;
  E   		numeric;
  M   		numeric;
BEGIN
  S := bit_copy(P, 31, 1);
  E := bit_copy(P, 23, 8);
  M := bit_copy(P, 0, 23);

  F := power(-1, S) * power(2, E - 127) * (1 + M / power(2, 23));

  RETURN F;
END
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION IEEE754_32(numeric) TO PUBLIC;

--------------------------------------------------------------------------------
-- IEEE754_64 ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION IEEE754_64 (
  P			numeric
) RETURNS 	numeric
AS
$$
DECLARE
  F   		numeric;
  S   		numeric;
  E   		numeric;
  M   		numeric;
BEGIN
  S := bit_copy(P, 63, 1);
  E := bit_copy(P, 52, 11);
  M := bit_copy(P, 0, 52);

  F := power(-1, S) * power(2, E - 1023) * (1 + M / power(2, 52));

  RETURN F;
END
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION IEEE754_64(numeric) TO PUBLIC;
