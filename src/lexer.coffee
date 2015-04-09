class Lexer
  constructor: (sql, opts={}) ->
    @sql = sql
    @preserveWhitespace = opts.preserveWhitespace || false
    @tokens = []
    @currentLine = 1
    @currentColumn = 0
    i = 0
    while @chunk = sql.slice(i)
      bytesConsumed =  @starToken() or
                       @booleanToken() or
                       @windowExtension() or
                       @sortOrderToken() or
                       @seperatorToken() or
                       @colonToken() or
                       @pipesToken() or
                       @operatorToken() or
                       @numberToken() or
                       @mathToken() or
                       @dotToken() or
                       @frameOpToken() or
                       @frameBoundToken() or
                       @stringToken() or
                       @parameterToken() or
                       @parensToken() or
                       @whitespaceToken() or
                       @keywordToken() or
                       @subSelectUnaryOpToken() or
                       @literalToken()
      throw new Error("NOTHING CONSUMED: Stopped at - '#{@chunk.slice(0,30)}'") if bytesConsumed < 1
      i += bytesConsumed
      @currentColumn += bytesConsumed
    @token('EOF', '')
    @postProcess()

  postProcess: ->
    for token, i in @tokens
      next_token = @tokens[i+1]
      if token[0] is 'STAR'
        unless next_token[0] is 'SEPARATOR' or next_token[0] is 'FROM' or next_token[0] is 'RIGHT_PAREN'
          token[0] = 'MATH_MULTI'
      if token[0] is 'DATE' or token[0] is 'TIMESTAMP' or token[0] is 'INTERVAL'
        unless next_token[0] is 'STRING'
          token[0] = 'LITERAL'
      if token[0] is 'RIGHT' or token[0] is 'LEFT'
        unless next_token[0] is 'OUTER' or next_token[0] is 'JOIN'
          token[0] = 'LITERAL'
      if token[0] is 'NUMBER' and next_token[0] is 'NUMBER' and next_token[1][0] == '-'
        next_token[1] = next_token[1].slice(1)
        @tokens.splice(i + 1, 0, ['MATH', '-', next_token[2]])
        @postProcess()
        return

  token: (name, value) ->
    # @tokens.push({name: name, value: value, line: @currentLine, col: @currentColumn})
    # console.log(name, value)
    @tokens.push([name, value, @currentLine])

  tokenizeFromRegex: (name, regex, part=0, lengthPart=part, output=true) ->
    return 0 unless match = regex.exec(@chunk)
    partMatch = match[part]
    @token(name, partMatch) if output
    return match[lengthPart].length

  tokenizeFromWord: (name, word=name) ->
    word = @regexEscape(word)
    matcher = if (/^\w+$/).test(word)
      new RegExp("^(#{word})\\b",'ig')
    else
      new RegExp("^(#{word})",'ig')
    match = matcher.exec(@chunk)
    return 0 unless match
    @token(name, match[1])
    return match[1].length

  tokenizeFromList: (name, list) ->
    ret = 0
    for entry in list
      ret = @tokenizeFromWord(name, entry)
      break if ret > 0
    ret

  keywordToken: ->
    @tokenizeFromWord('SELECT') or
    @tokenizeFromWord('WITH') or
    @tokenizeFromWord('WITHIN') or
    @tokenizeFromWord('DISTINCT') or
    @tokenizeFromWord('FROM') or
    @tokenizeFromWord('WHERE') or
    @tokenizeFromWord('GROUP') or
    @tokenizeFromWord('ORDER') or
    @tokenizeFromWord('BY') or
    @tokenizeFromWord('HAVING') or
    @tokenizeFromWord('LIMIT') or
    @tokenizeFromWord('JOIN') or
    @tokenizeFromWord('LEFT') or
    @tokenizeFromWord('RIGHT') or
    @tokenizeFromWord('INNER') or
    @tokenizeFromWord('OUTER') or
    @tokenizeFromWord('FULL') or
    @tokenizeFromWord('ON') or
    @tokenizeFromWord('AS') or
    @tokenizeFromWord('UNION') or
    @tokenizeFromWord('ALL') or
    @tokenizeFromWord('ANY') or
    @tokenizeFromWord('SOME') or
    @tokenizeFromWord('NOT') or
    @tokenizeFromWord('IN') or
    @tokenizeFromWord('AND') or
    @tokenizeFromWord('OR') or
    @tokenizeFromWord('DATE') or
    @tokenizeFromWord('LIMIT') or
    @tokenizeFromWord('OFFSET') or
    @tokenizeFromWord('FETCH') or
    @tokenizeFromWord('ONLY') or
    @tokenizeFromWord('NEXT') or
    @tokenizeFromWord('FIRST') or
    @tokenizeFromWord('USING') or
    @tokenizeFromWord('CASE') or
    @tokenizeFromWord('BETWEEN') or
    @tokenizeFromWord('WHEN') or
    @tokenizeFromWord('THEN') or
    @tokenizeFromWord('ELSE') or
    @tokenizeFromWord('END') or
    @tokenizeFromWord('EXTRACT') or
    @tokenizeFromWord('CAST') or
    @tokenizeFromWord('TIMESTAMP') or
    @tokenizeFromWord('INTERVAL') or
    @tokenizeFromWord('PARTITION') or
    @tokenizeFromWord('OVER') or
    @tokenizeFromWord('PRECEDING') or
    @tokenizeFromWord('FOLLOWING')

  dotToken: -> @tokenizeFromWord('DOT', '.')
  operatorToken:    -> @tokenizeFromList('OPERATOR', SQL_OPERATORS)
  mathToken:        ->
    @tokenizeFromList('MATH', MATH) or
    @tokenizeFromList('MATH_MULTI', MATH_MULTI)
  subSelectOpToken: -> @tokenizeFromList('SUB_SELECT_OP', SUB_SELECT_OP)
  subSelectUnaryOpToken: -> @tokenizeFromList('SUB_SELECT_UNARY_OP', SUB_SELECT_UNARY_OP)
  frameOpToken:     -> @tokenizeFromList('FRAME_OP', FRAME_OP)
  frameBoundToken:  -> @tokenizeFromList('FRAME_BOUND', FRAME_BOUND)
  functionToken:    -> @tokenizeFromList('FUNCTION', SQL_FUNCTIONS)
  sortOrderToken:   -> @tokenizeFromList('DIRECTION', SQL_SORT_ORDERS)
  booleanToken:     -> @tokenizeFromList('BOOLEAN', BOOLEAN)

  starToken:        -> @tokenizeFromRegex('STAR', STAR)
  seperatorToken:   -> @tokenizeFromRegex('SEPARATOR', SEPARATOR)
  colonToken:       -> @tokenizeFromRegex('COLON', COLON)
  pipesToken:       -> @tokenizeFromRegex('PIPES', PIPES)
  literalToken:     -> @tokenizeFromRegex('LITERAL', LITERAL, 1, 0)
  numberToken:      -> @tokenizeFromRegex('NUMBER', NUMBER)
  parameterToken:   -> @tokenizeFromRegex('PARAMETER', PARAMETER)
  stringToken:      ->
    @tokenizeFromRegex('STRING', STRING, 1, 0) ||
    @tokenizeFromRegex('DBLSTRING', DBLSTRING, 1, 0)


  parensToken: ->
    @tokenizeFromRegex('LEFT_PAREN', /^\(/,) or
    @tokenizeFromRegex('RIGHT_PAREN', /^\)/,)

  windowExtension: ->
    match = (/^\.(win):(length|time)/i).exec(@chunk)
    return 0 unless match
    @token('WINDOW', match[1])
    @token('WINDOW_FUNCTION', match[2])
    match[0].length

  whitespaceToken: ->
    return 0 unless match = WHITESPACE.exec(@chunk)
    partMatch = match[0]
    newlines = partMatch.replace(/[^\n]/, '').length
    @currentLine += newlines
    @token(name, partMatch) if @preserveWhitespace
    return partMatch.length

  regexEscape: (str) ->
    str.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&")

  SQL_FUNCTIONS       = ['AVG', 'MIN', 'MAX', 'SUM']
  SQL_SORT_ORDERS     = ['ASC', 'DESC']
  SQL_OPERATORS       = ['=', '!=', '>=', '>', '<=', '<>', '<', 'LIKE', 'NOT LIKE', 'ILIKE', 'NOT ILIKE', 'IS NOT', 'IS', '~~*', '~~', '!~~*', '!~~', '~*', '~', '!~*', '!~', '!']
  SUB_SELECT_OP       = ['IN', 'NOT IN', 'ANY', 'ALL', 'SOME']
  SUB_SELECT_UNARY_OP = ['EXISTS']
  FRAME_OP            = ['RANGE', 'ROWS']
  FRAME_BOUND         = ['UNBOUNDED PRECEDING', 'CURRENT ROW', 'UNBOUNDED FOLLOWING']
  SQL_CONDITIONALS    = ['AND', 'OR']
  BOOLEAN             = ['TRUE', 'FALSE', 'NULL']
  MATH                = ['+', '-']
  MATH_MULTI          = ['/', '*', '^']
  STAR                = /^\*/
  SEPARATOR           = /^,/
  COLON               = /^:/
  PIPES               = /^\|\|/
  WHITESPACE          = /^[ \n\t\r]+/
  LITERAL             = /^`?([a-z_][a-z0-9_$]{0,})`?/i
  PARAMETER           = /^\$[0-9]+/
  NUMBER              = /^-?[0-9]+\.?([0-9]+)?|^\.[0-9]+/
  STRING              = /^'([^\\']*(?:\\.[^\\']*)*)'/
  DBLSTRING           = /^"([^\\"]*(?:\\.[^\\"]*)*)"/



exports.tokenize = (sql, opts) -> (new Lexer(sql, opts)).tokens

