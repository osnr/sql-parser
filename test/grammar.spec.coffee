lexer = require('../lib/lexer')
parser = require("../lib/parser")

parse = (query) ->
  parser.parse(lexer.tokenize(query))

describe "SQL Grammar", ->
  describe "SELECT Queries", ->

    it "parses count(*)", ->
      parse("select count(*) from x.y").toString().should.eql """
      SELECT COUNT(*)
        FROM `x.y`
      """

    it "parses a string", ->
      parse("select 'wut'").toString().should.eql """
      SELECT 'wut'
      """

    it "parses a case statement", ->
      parse("select case x when 'y' then False when 'z' then False else True END from t").toString().should.eql """
      SELECT CASE `x`
          WHEN 'y' THEN FALSE
          WHEN 'z' THEN FALSE
          ELSE TRUE
        END
        FROM `t`
      """

    it "parses shorthand aliases", ->
      parse("select date_trunc('month', t.x) y from t").toString().should.eql """
      SELECT DATE_TRUNC('month', `t.x`) AS `y`
        FROM `t`
      """

    it "parses x=y", ->
      parse("select x=y FROM t").toString().should.eql """
      SELECT (`x` = `y`)
        FROM `t`
      """

    it "parses expressions inside functions", ->
      parse("select date_trunc('day', timestamp 'EPOCH' + x * (INTERVAL '1 second')) FROM t").toString().should.eql """
      SELECT DATE_TRUNC('day', (TIMESTAMP 'EPOCH' + (`x` * INTERVAL '1 second')))
        FROM `t`
      """

    it "parses negative numbers", ->
      parse("select x from t where y = -50").toString().should.eql """
      SELECT `x`
        FROM `t`
        WHERE (`y` = -50)
      """

    it "parses between", ->
      parse("select count(not y), x from t where x between 1 and 2").toString().should.eql """
      SELECT COUNT((NOT `y`)), `x`
        FROM `t`
        WHERE `x` BETWEEN 1 AND 2
      """

    it "parses window functions: partition", ->
      parse("select sum(x) over (partition by y) as z from t").toString().should.eql """
      SELECT SUM(`x`) OVER (PARTITION BY `y`) AS `z`
        FROM `t`
      """

    it "parses window functions: partition + order", ->
      parse("select sum(x) over (partition by y order by x asc) as z from t").toString().should.eql """
      SELECT SUM(`x`) OVER (PARTITION BY `y` ORDER BY `x` asc) AS `z`
        FROM `t`
      """

    it "parses window functions: partition + frame", ->
      parse("select sum(x) over (partition by y rows 3 preceding) as z from t").toString().should.eql """
      SELECT SUM(`x`) OVER (PARTITION BY `y` rows 3 preceding) AS `z`
        FROM `t`
      """

    it "parses window functions: partition + frame between", ->
      parse("select sum(x) over (partition by y range between unbounded preceding and current row) as z from t").toString().should.eql """
      SELECT SUM(`x`) OVER (PARTITION BY `y` range BETWEEN unbounded preceding AND current row) AS `z`
        FROM `t`
      """

    it "parses case", ->
      parse("select cast(x as double) from t").toString().should.eql """
      SELECT CAST(`x` AS `double`)
        FROM `t`
      """

    it "parses functions without arguments", ->
      parse("select now()").toString().should.eql """
      SELECT NOW()
      """

    it "parses window functions without arguments", ->
      parse("select median(x) over ()").toString().should.eql """
      SELECT MEDIAN(`x`) OVER ()
      """

    it "parses date math", ->
      parse("select date '2014-01-01' - interval '5 hours'").toString().should.eql """
      SELECT (DATE '2014-01-01' - INTERVAL '5 hours')
      """

      parse("select x.date from y").toString().should.eql """
      SELECT `x.date`
        FROM `y`
      """

    it "parses an extract statement", ->
      parse("select extract(epoch from timestamp '2015-01-01')").toString().should.eql """
      SELECT EXTRACT(`epoch` FROM TIMESTAMP '2015-01-01')
      """

    it "parses ORDER BY clauses", ->
      parse("SELECT * FROM my_table ORDER BY x DESC").toString().should.eql """
      SELECT *
        FROM `my_table`
        ORDER BY `x` DESC
      """

    it "parses GROUP BY clauses", ->
      parse("SELECT * FROM my_table GROUP BY x, y").toString().should.eql """
      SELECT *
        FROM `my_table`
        GROUP BY `x`, `y`
      """

    it "parses LIMIT clauses", ->
      parse("SELECT * FROM my_table LIMIT 10").toString().should.eql """
      SELECT *
        FROM `my_table`
        LIMIT 10
      """

    it "parses LIMIT clauses after ORDER BY", ->
      parse("SELECT * FROM my_table ORDER BY cat DESC LIMIT 10").toString().should.eql """
      SELECT *
        FROM `my_table`
        ORDER BY `cat` DESC
        LIMIT 10
      """

    it "parses LIMIT clauses with comma separated offset", ->
      parse("SELECT * FROM my_table LIMIT 30, 10").toString().should.eql """
      SELECT *
        FROM `my_table`
        LIMIT 10
        OFFSET 30
      """

    it "parses LIMIT clauses with OFFSET keyword", ->
      parse("SELECT * FROM my_table LIMIT 10 OFFSET 30").toString().should.eql """
      SELECT *
        FROM `my_table`
        LIMIT 10
        OFFSET 30
      """

    it "parses SELECTs with FUNCTIONs", ->
      parse("SELECT a, COUNT(1, b) FROM my_table LIMIT 10").toString().should.eql """
      SELECT `a`, COUNT(1, `b`)
        FROM `my_table`
        LIMIT 10
      """

    it "parses COUNT(DISTINCT field)", ->
      parse("select a, count(distinct b) FROM my_table limit 10").toString().should.eql """
      SELECT `a`, COUNT(DISTINCT `b`)
        FROM `my_table`
        LIMIT 10
      """

    it "parses WHERE clauses", ->
      parse("SELECT * FROM my_table WHERE x > 1 AND y = 'foo'").toString().should.eql """
      SELECT *
        FROM `my_table`
        WHERE ((`x` > 1) AND (`y` = 'foo'))
      """

    it "parses complex WHERE clauses", ->
      parse("SELECT * FROM my_table WHERE a > 10 AND (a < 30 OR b = 'c')").toString().should.eql """
      SELECT *
        FROM `my_table`
        WHERE ((`a` > 10) AND ((`a` < 30) OR (`b` = 'c')))
      """

    it "parses WHERE with ORDER BY clauses", ->
      parse("SELECT * FROM my_table WHERE x > 1 ORDER BY y").toString().should.eql """
      SELECT *
        FROM `my_table`
        WHERE (`x` > 1)
        ORDER BY `y` ASC
      """

    it "parses WHERE with multiple ORDER BY clauses", ->
      parse("SELECT * FROM my_table WHERE x > 1 ORDER BY x, y DESC").toString().should.eql """
      SELECT *
        FROM `my_table`
        WHERE (`x` > 1)
        ORDER BY `x` ASC, `y` DESC
      """

    it "parses WHERE with ORDER BY clauses with direction", ->
      parse("SELECT * FROM my_table WHERE x > 1 ORDER BY y ASC").toString().should.eql """
      SELECT *
        FROM `my_table`
        WHERE (`x` > 1)
        ORDER BY `y` ASC
      """

    it "parses WHERE with GROUP BY clauses", ->
      parse("SELECT * FROM my_table WHERE x > 1 GROUP BY x, y").toString().should.eql """
      SELECT *
        FROM `my_table`
        WHERE (`x` > 1)
        GROUP BY `x`, `y`
      """

    it "parses WHERE with GROUP BY and ORDER BY clauses", ->
      parse("SELECT * FROM my_table WHERE x > 1 GROUP BY x, y ORDER BY COUNT(y) ASC").toString().should.eql """
      SELECT *
        FROM `my_table`
        WHERE (`x` > 1)
        GROUP BY `x`, `y`
        ORDER BY COUNT(`y`) ASC
      """

    it "parses GROUP BY and HAVING clauses", ->
      parse("SELECT * FROM my_table GROUP BY x, y HAVING COUNT(`y`) > 1").toString().should.eql """
      SELECT *
        FROM `my_table`
        GROUP BY `x`, `y`
        HAVING (COUNT(`y`) > 1)
      """

    it "parses UDFs", ->
      parse("SELECT LENGTH(a) FROM my_table").toString().should.eql """
      SELECT LENGTH(`a`)
        FROM `my_table`
      """

    it "parses expressions in place of fields", ->
      parse("SELECT f+LENGTH(f)/3 AS f1 FROM my_table").toString().should.eql """
      SELECT (`f` + (LENGTH(`f`) / 3)) AS `f1`
        FROM `my_table`
      """

    it "supports booleans", ->
      parse("SELECT null FROM my_table WHERE a = true").toString().should.eql """
      SELECT NULL
        FROM `my_table`
        WHERE (`a` = TRUE)
      """

    it "supports IS and IS NOT", ->
      parse("SELECT * FROM my_table WHERE a IS NULL AND b IS NOT NULL").toString().should.eql """
      SELECT *
        FROM `my_table`
        WHERE ((`a` IS NULL) AND (`b` IS NOT NULL))
      """

    it "supports nested expressions", ->
      parse("SELECT * FROM my_table WHERE MOD(LENGTH(a) + LENGTH(b), c)").toString().should.eql """
      SELECT *
        FROM `my_table`
        WHERE MOD((LENGTH(`a`) + LENGTH(`b`)), `c`)
      """

    it "supports nested fields using dot syntax", ->
      parse("SELECT a.b.c FROM my_table WHERE a.b > 2").toString().should.eql """
      SELECT `a.b.c`
        FROM `my_table`
        WHERE (`a.b` > 2)
      """

    it "supports quoted fields", ->
      parse('SELECT a."b" FROM c').toString().should.eql """
      SELECT `a."b"`
        FROM `c`
      """

    it "supports time window extensions", ->
      parse("SELECT * FROM my_table.win:length(123)").toString().should.eql """
      SELECT *
        FROM `my_table`.win:length(123)
      """

    it "parses sub selects", ->
      parse("select * from (select * from my_table)").toString().should.eql """
      SELECT *
        FROM (
          SELECT *
            FROM `my_table`
        )
      """

    it "parses named sub selects", ->
      parse("select * from (select * from my_table) t").toString().should.eql """
      SELECT *
        FROM (
          SELECT *
            FROM `my_table`
        ) `t`
      """

    it "parses single joins", ->
      parse("select * from a join b on a.id = b.id").toString().should.eql """
      SELECT *
        FROM `a`
        JOIN `b`
          ON (`a.id` = `b.id`)
      """

    it "parses right outer joins", ->
      parse("select * from a right outer join b on a.id = b.id").toString().should.eql """
      SELECT *
        FROM `a`
        RIGHT OUTER JOIN `b`
          ON (`a.id` = `b.id`)
      """

      parse("select right(x) from y").toString().should.eql """
      SELECT RIGHT(`x`)
        FROM `y`
      """

      parse("SELECT x.* from y").toString().should.eql """
      SELECT `x.*`
        FROM `y`
      """

      parse("select * from x full join y on z").toString().should.eql """
      SELECT *
        FROM `x`
        FULL JOIN `y`
          ON `z`
      """

      parse("select mode() within group (order by x) over (partition by a,b) from y").toString().should.eql """
      SELECT MODE() WITHIN GROUP (ORDER BY `x` ASC) OVER (PARTITION BY `a`, `b`)
        FROM `y`
      """

      parse("select cast(x as timestamp)").toString().should.eql """
        SELECT CAST(`x` AS `timestamp`)
      """

      parse("select convert(int, 2015-01-01)").toString().should.eql """
        SELECT CONVERT(`int`, ((2015 - 1) - 1))
      """

      parse("select x::timestamp").toString().should.eql """
        SELECT `x`::`timestamp`
      """

      parse("with x as (select * from y union select * from z) select * from x").toString().should.eql """
        WITH
          `x` AS (
            SELECT *
              FROM `y`
            UNION
            SELECT *
              FROM `z`
          )
        SELECT *
          FROM `x`
      """

    it "parses multiple joins", ->
      parse("select * from a join b on a.id = b.id join c on a.id = c.id").toString().should.eql """
      SELECT *
        FROM `a`
        JOIN `b`
          ON (`a.id` = `b.id`)
        JOIN `c`
          ON (`a.id` = `c.id`)
      """

    it "ok", ->
      return
      parse("""
select count(latest_dispute__reason_code = '83') as disputed, count(*) as total, (count(latest_dispute__reason_code = '83')::double precision / count(*)::double precision) as per
      """).toString().should.eql """
      """

    it "parses using", ->
      parse("select * from a join b using(c)").toString().should.eql """
      SELECT *
        FROM `a`
        JOIN `b`
          USING(`c`)
      """

    it "parses string concat", ->
      parse("select a || b").toString().should.eql """
      SELECT (`a` || `b`)
      """

    it "parses floats", ->
      parse("select 100.").toString().should.eql """
      SELECT 100
      """

    it "parses UNIONs", ->
      parse("select * from a union select * from b").toString().should.eql """
      SELECT *
        FROM `a`
      UNION
      SELECT *
        FROM `b`
      """

    it "parses UNION ALL", ->
      parse("select * from a union all select * from b").toString().should.eql """
      SELECT *
        FROM `a`
      UNION ALL
      SELECT *
        FROM `b`
      """

  describe "string quoting", ->
    it "doesn't choke on escaped quotes", ->
      parse("select * from a where foo = 'I\\'m'").toString().should.eql """
      SELECT *
        FROM `a`
        WHERE (`foo` = 'I\\'m')
      """

    it "allows using double quotes", ->
      parse('select * from a where foo = "a"').toString().should.eql """
      SELECT *
        FROM `a`
        WHERE (`foo` = "a")
      """

    it "allows nesting different quote styles", ->
      parse("""select * from a where foo = "I'm" """).toString().should.eql """
      SELECT *
        FROM `a`
        WHERE (`foo` = "I'm")
      """

  describe "subselect clauses", ->
    it "parses an IN clause containing a list", ->
      parse("""select * from a where x in (1,2,3)""").toString().should.eql """
      SELECT *
        FROM `a`
        WHERE (`x` IN (1, 2, 3))
      """

    it "parses an IN clause containing a query", ->
      parse("""select * from a where x in (select foo from bar)""").toString().should.eql """
      SELECT *
        FROM `a`
        WHERE (`x` IN (
          SELECT `foo`
            FROM `bar`
        ))
      """

    it "parses a NOT IN clause containing a query", ->
      parse("""select * from a where x not in (select foo from bar)""").toString().should.eql """
      SELECT *
        FROM `a`
        WHERE (`x` NOT IN (
          SELECT `foo`
            FROM `bar`
        ))
      """

    it "parses an EXISTS clause containing a query", ->
      parse("""select * from a where exists (select foo from bar)""").toString().should.eql """
      SELECT *
        FROM `a`
        WHERE (EXISTS (
          SELECT `foo`
            FROM `bar`
        ))
      """

  describe "aliases", ->
    it "parses aliased table names", ->
      parse("""select * from a b""").toString().should.eql """
      SELECT *
        FROM `a` AS `b`
      """

    it "parses aliased table names with as", ->
      parse("""select * from a as b""").toString().should.eql """
      SELECT *
        FROM `a` AS `b`
      """

  describe "STARS", ->
    it "parses stars as multiplcation", ->
      parse('SELECT * FROM foo WHERE a = 1*2').toString().should.eql """
      SELECT *
        FROM `foo`
        WHERE (`a` = (1 * 2))
      """

  describe "Parameters", ->
    it "parses query parameters", ->
      parse('select * from foo where bar = $12').toString().should.eql """
      SELECT *
        FROM `foo`
        WHERE (`bar` = $12)
      """

  describe "WITH", ->
    it "parses a single with statement", ->
      parse('with a as (select id from t1) select max(id) from a').toString().should.eql """
      WITH
        `a` AS (
          SELECT `id`
            FROM `t1`
        )
      SELECT MAX(`id`)
        FROM `a`
      """
    it "parses multiple with statements", ->
      parse('with a as (select count(id) from t1), b as (select max(id) from t2) select count(id) from a, b').toString().should.eql """
      WITH
        `a` AS (
          SELECT COUNT(`id`)
            FROM `t1`
        ),
        `b` AS (
          SELECT MAX(`id`)
            FROM `t2`
        )
      SELECT COUNT(`id`)
        FROM `a`,`b`
      """
