{Parser} = require 'jison'

unwrap = /^function\s*\(\)\s*\{\s*return\s*([\s\S]*);\s*\}/

o = (patternString, action, options) ->
  patternString = patternString.replace /\s{2,}/g, ' '
  return [patternString, '$$ = $1;', options] unless action
  action = if match = unwrap.exec action then match[1] else "(#{action}())"
  action = action.replace /\bnew /g, '$&yy.'
  [patternString, "$$ = #{action};", options]

grammar =

  Root: [
    o 'Query EOF'
    o "WithQuery EOF"
  ]

  Query: [
    o "SelectQuery"
    o "SelectQuery Unions",                                -> $1.unions = $2; $1
  ]

  WithQuery: [
    o "WITH NamedQueries Query",                     -> new WithQuery($2, $3)
  ]

  NamedQueries: [
    o "NamedQuery",                                         -> [$1]
    o "NamedQueries SEPARATOR NamedQuery",                  -> $1.concat($3)
  ]

  NamedQuery: [
    o "Literal AS LEFT_PAREN Query RIGHT_PAREN",    -> new NamedQuery($1, $4)
  ]

  SelectQuery: [
    o "SelectWithLimitQuery"
    o "BasicSelectQuery"
  ]

  BasicSelectQuery: [
    o 'Select'
    o 'Select OrderClause',                               -> $1.order = $2; $1
    o 'Select GroupClause',                               -> $1.group = $2; $1
    o 'Select GroupClause OrderClause',                   -> $1.group = $2; $1.order = $3; $1
  ]

  SelectWithLimitQuery: [
    o 'SelectQuery LimitClause',                          -> $1.limit = $2; $1
  ]

  Select: [
    o 'SelectClause'
    o 'SelectClause WhereClause',                         -> $1.where = $2; $1
  ]

  SelectClause: [
    o 'SELECT Fields',                                    -> new Select($2, null, false)
    o 'SELECT Fields FROM Tables',                        -> new Select($2, $4, false)
    o 'SELECT DISTINCT Fields FROM Tables',                -> new Select($3, $5, true)
    o 'SELECT Fields FROM Table Joins',                   -> new Select($2, $4, false, $5)
    o 'SELECT DISTINCT Fields FROM Table Joins',          -> new Select($3, $5, true, $6)
  ]

  Tables: [
    o 'Table',                                          -> [$1]
    o 'Tables SEPARATOR Table',                         -> $1.concat($3)
  ]

  Table: [
    o 'Literal',                                          -> new Table($1)
    o 'Literal Literal',                                  -> new Table($1, $2)
    o 'Literal AS Literal',                               -> new Table($1, $3)
    o 'LEFT_PAREN List RIGHT_PAREN',                      -> $2
    o 'LEFT_PAREN Query RIGHT_PAREN',                     -> new SubSelect($2)
    o 'LEFT_PAREN Query RIGHT_PAREN AS Literal',             -> new SubSelect($2, $5)
    o 'LEFT_PAREN Query RIGHT_PAREN Literal',             -> new SubSelect($2, $4)
    o 'Literal WINDOW WINDOW_FUNCTION LEFT_PAREN Number RIGHT_PAREN',
                                                          -> new Table($1, null, $2, $3, $5)
  ]

  Unions: [
    o 'Union',                                            -> [$1]
    o 'Unions Union',                                     -> $1.concat($2)
  ]

  Union: [
    o 'UNION SelectQuery',                                -> new Union($2)
    o 'UNION ALL SelectQuery',                            -> new Union($3, true)
  ]

  Joins: [
    o 'Join',                                             -> [$1]
    o 'Joins Join',                                       -> $1.concat($2)
  ]

  Join: [
    o 'JOIN Table JoinPredicate',                         -> new Join($2, $3)
    o 'INNER JOIN Table JoinPredicate',                   -> new Join($2, $4)
    o 'LEFT JOIN Table JoinPredicate',                    -> new Join($3, $4, 'LEFT')
    o 'RIGHT JOIN Table JoinPredicate',                   -> new Join($3, $4, 'RIGHT')
    o 'LEFT INNER JOIN Table JoinPredicate',              -> new Join($4, $5, 'LEFT', 'INNER')
    o 'RIGHT INNER JOIN Table JoinPredicate',             -> new Join($4, $5, 'RIGHT', 'INNER')
    o 'LEFT OUTER JOIN Table JoinPredicate',              -> new Join($4, $5, 'LEFT', 'OUTER')
    o 'RIGHT OUTER JOIN Table JoinPredicate',             -> new Join($4, $5, 'RIGHT', 'OUTER')
    o 'FULL OUTER JOIN Table JoinPredicate',              -> new Join($4, $5, 'FULL', 'OUTER')
    o 'FULL JOIN Table JoinPredicate',                    -> new Join($3, $4, 'FULL')
  ]

  JoinPredicate: [
    o 'ON Expression',                                 -> $2
    o 'USING LEFT_PAREN Literal RIGHT_PAREN',           -> new Using($3)
  ]

  WhereClause: [
    o 'WHERE Expression',                                 -> new Where($2)
  ]

  LimitClause: [
    o 'LIMIT Number',                                     -> new Limit($2)
    o 'LIMIT Number SEPARATOR Number',                    -> new Limit($4, $2)
    o 'LIMIT Number OFFSET Number',                       -> new Limit($2, $4)
  ]

  OrderClause: [
    o 'ORDER BY OrderArgs',                               -> new Order($3)
    o 'ORDER BY OrderArgs OffsetClause',                  -> new Order($3, $4)
  ]

  OrderArgs: [
    o 'OrderArg',                                         -> [$1]
    o 'OrderArgs SEPARATOR OrderArg',                     -> $1.concat($3)
  ]

  OrderArg: [
    o 'Value',                                            -> new OrderArgument($1, 'ASC')
    o 'Value DIRECTION',                                  -> new OrderArgument($1, $2)
  ]

  OffsetClause: [
    # MS SQL Server 2012+
    o 'OFFSET OffsetRows',                                -> new Offset($2)
    o 'OFFSET OffsetRows FetchClause',                    -> new Offset($2, $3)
  ]

  OffsetRows: [
    o 'Number ROW',                                       -> $1
    o 'Number ROWS',                                      -> $1
  ]

  FetchClause: [
    o 'FETCH FIRST OffsetRows ONLY',                      -> $3
    o 'FETCH NEXT OffsetRows ONLY',                       -> $3
  ]

  GroupClause: [
    o 'GroupBasicClause'
    o 'GroupBasicClause HavingClause',                    -> $1.having = $2; $1
  ]

  GroupBasicClause: [
    o 'GROUP BY ArgumentList',                            -> new Group($3)
  ]

  HavingClause: [
    o 'HAVING Expression',                                -> new Having($2)
  ]

  Expressions: [
    o 'Expression',                                      -> [$1]
    o 'Expressions SEPARATOR Expression',               -> $1.concat($3)
  ]


  Expression: [
    o 'LEFT_PAREN Expression RIGHT_PAREN',                -> $2
    o 'Expression MATH Expression',                       -> new Op($2, $1, $3)
    o 'Expression MATH_MULTI Expression',                 -> new Op($2, $1, $3)
    o 'Expression OPERATOR Expression',                   -> new Op($2, $1, $3)
    o 'Expression AND Expression',                        -> new Op($2, $1, $3)
    o 'Expression OR Expression',                         -> new Op($2, $1, $3)
    o 'Expression PIPES Expression',                      -> new Op($2, $1, $3)
    o 'Expression BETWEEN Expression AND Expression',                   -> new Between($1, $3, $5)
    o 'Value SubSelectOp LEFT_PAREN List RIGHT_PAREN',  -> new Op($2, $1, $4)
    o 'Value SubSelectOp SubSelectExpression',          -> new Op($2, $1, $3)
    o 'Value SubSelectOp Expression',          -> new Op($2, $1, $3)
    o 'SUB_SELECT_UNARY_OP SubSelectExpression',          -> new UnaryOp($1, $2)
    o 'EXTRACT LEFT_PAREN Value FROM Expression RIGHT_PAREN', -> new Extract($3, $5)
    o 'CAST LEFT_PAREN Expression AS Literal RIGHT_PAREN', -> new Cast($3, $5)
    o 'CAST LEFT_PAREN Expression AS Literal Literal RIGHT_PAREN', -> new Cast($3, $5+' '+$6)
    o 'Expression COLON COLON Literal', -> new Cast($1, $4, true)
    o 'NOT Expression',          -> new UnaryOp($1, $2)
    o 'Expression WITHIN GROUP LEFT_PAREN OrderClause RIGHT_PAREN',  -> new WithinGroup($1, $5)
    o 'CaseStatement'
    o 'WindowExpression'
    o 'Value'
    o 'Query'
  ]

  SubSelectOp: [
    o 'IN'
    o 'NOT IN', -> $1+' '+$2
    o 'ANY'
    o 'ALL'
    o 'SOME'
  ]

  WindowExpression: [
    o 'Expression OVER LEFT_PAREN RIGHT_PAREN', -> new Window($1, null)
    o 'Expression OVER LEFT_PAREN FrameExpressions RIGHT_PAREN', -> new Window($1, $4)
  ]

  FrameExpressions: [
    o 'FrameExpression', -> [$1]
    o 'FrameExpressions FrameExpression', -> $1.concat($2)
  ]

  FrameExpression: [
    o 'PARTITION BY Expressions', -> new Partition($3)
    o 'OrderClause'
    o 'FrameClause'
  ]

  FrameClause: [
    o 'FRAME_OP FrameBound', -> new Frame($1, $2)
    o 'FRAME_OP BETWEEN FrameBound AND FrameBound', -> new Frame($1, $3, $5)
  ]

  FrameBound: [
    o 'Value PRECEDING', -> new FrameBound($1, $2)
    o 'Value FOLLOWING', -> new FrameBound($1, $2)
    o 'FRAME_BOUND', -> new FrameBound($1)
  ]

  CaseStatement: [
    o 'CASE WhenStatements END',                       -> new Case(null, $2)
    o 'CASE Expression WhenStatements END',                       -> new Case($2, $3)
  ]

  WhenStatements: [
    o 'WhenStatement',                                      -> [$1]
    o 'WhenStatements WhenStatement',                       -> $1.concat($2)
    o 'WhenStatements ElseStatement',                       -> $1.concat($2)
  ]

  WhenStatement: [
    o 'WHEN Expression THEN Expression',                       -> new When($2, $4)
  ]

  ElseStatement: [
    o 'ELSE Expression',                                       -> new Else($2)
  ]

  SubSelectExpression: [
    o 'LEFT_PAREN Query RIGHT_PAREN',                     -> new SubSelect($2)
  ]

  Value: [
    o 'Literal'
    o 'DATE Value', -> new DateValue($2)
    o 'TIMESTAMP Value', -> new Timestamp($2)
    o 'INTERVAL Value', -> new Interval($2)
    o 'Number'
    o 'String'
    o 'UserFunction'
    o 'Boolean'
    o 'Parameter'
    o 'Value COLON COLON Literal', -> new Cast($1, $4, true)
  ]

  List: [
    o 'ArgumentList',                                     -> new ListValue($1)
  ]

  Number: [
    o 'NUMBER',                                           -> new NumberValue($1)
  ]

  Boolean: [
    o 'BOOLEAN',                                           -> new BooleanValue($1)
  ]

  Parameter: [
    o 'PARAMETER',                                        -> new ParameterValue($1)
  ]

  String: [
    o 'STRING',                                           -> new StringValue($1, "'")
    o 'DBLSTRING',                                        -> new StringValue($1, '"')
  ]

  Literal: [
    o 'String',                                          -> new LiteralValue($1)
    o 'LITERAL',                                          -> new LiteralValue($1)
    o 'Literal DOT String',                              -> new LiteralValue($1, $3)
    o 'Literal DOT LITERAL',                              -> new LiteralValue($1, $3)
    o 'Literal DOT STAR',                              -> new LiteralValue($1, $3)
  ]

  Function: [
    o "FUNCTION LEFT_PAREN AggregateArgumentList RIGHT_PAREN",     -> new FunctionValue($1, $3)
  ]

  UserFunction: [
    o "LITERAL LEFT_PAREN RIGHT_PAREN",     -> new FunctionValue($1, null, true)
    o "LITERAL LEFT_PAREN AggregateArgumentList RIGHT_PAREN",     -> new FunctionValue($1, $3, true)
  ]

  AggregateArgumentList: [
    o 'ArgumentList',                                    -> new ArgumentListValue($1)
    o 'DISTINCT ArgumentList',                           -> new ArgumentListValue($2, 'DISTINCT')
    o 'ALL ArgumentList',                                -> new ArgumentListValue($2, 'ALL')
  ]

  ArgumentList: [
    o 'STAR',                                            -> [$1]
    o 'Expression',                                       -> [$1]
    o 'ArgumentList SEPARATOR Expression',                     -> $1.concat($3)
  ]

  Fields: [
    o 'Field',                                            -> [$1]
    o 'Fields SEPARATOR Field',                           -> $1.concat($3)
  ]

  Field: [
    o 'STAR',                                             -> new Star()
    o 'Expression',                                       -> new Field($1)
    o 'Expression AS Literal',                            -> new Field($1, $3)
  ]

tokens = []
operators = [
  ['left', 'Op']
  ['left', 'MATH_MULTI']
  ['left', 'MATH']
  ['left', 'OPERATOR']
  ['left', 'CONDITIONAL']
]

for name, alternatives of grammar
  grammar[name] = for alt in alternatives
    for token in alt[0].split ' '
      tokens.push token unless grammar[token]
    alt[1] = "return #{alt[1]}" if name is 'Root'
    alt

exports.parser = new Parser
  tokens      : tokens.join ' '
  bnf         : grammar
  operators   : operators.reverse()
  startSymbol : 'Root'
