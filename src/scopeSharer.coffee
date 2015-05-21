_ = require 'lodash'
isArray = Array.isArray
isString = (str) -> typeof str is 'string'
isUndef = (o) -> typeof o is 'undefined'
isObject = (o) -> Object::toString.call(o) is '[object Object]'
isErrmsg = (o) -> not isUndef(o?.code)
isMiddleware = (fn) ->
  unless fn then return false
  str = fn.toString()
  reg = /^function\s+\(([^\)]+)\)/
  argStr = str.match(reg)?[1].replace(/\s+/g, '') or ''
  if ~argStr.indexOf 'req,res,next'
    return true
  else
    return false
isTable = (arr) ->
  if arr[0] and isArray arr[0]
    return true
  else
    false

ScopeSharer =  (root={}, opts)->
  ROOT = root
  OPTS = opts or {debug: true}
  FNS = OPTS.fns or []
  
  stackCounter = 0

  # group arguments to setters, debuggers and getters
  analysis = (arr) ->
    unless isArray(arr) then return [ [], [], [] ]
    setters = []
    debuggers = []
    getters = []
    arr.forEach (a) ->
      isStr = isString(a)
      if isStr
        if a.charAt(0) is '>'
          setters.push a
        else if a.charAt(0) is '?'
          debuggers.push a
        else
          getters.push a
      else
        getters.push a
    return [ getters, setters, debuggers ]

  # '$task.name' => ROOT.task.name
  __get__ = (str) ->
    GetReg = /^\$[\w\.]+|\$\{[\w\.]+\}|\$[\w\.]+$/g
    if typeof str is 'string'
      matches = str.match GetReg
      # case "$task.name"
      if str.charAt(0) is '$' and matches.length is 1
        return get(str)
      # case "asd${test}acac"
      else if GetReg.test str
        vals = matches.map get
        res = str.replace(GetReg, (match) -> return vals.shift())
        return res
      else
        return str
    else if isArray(str)
      return str.map (s) -> __get__(s)
    else if isObject(str)
      for key, val of str
        str[key] = __get__(val)
      return str
    else
      return str

  # ['a'], {} => ROOT.a = {}
  # ['[a, b, c]'], [a, b, c] => ROOT = {a:a, b:b, c:c}
  # ['{a, b, c}'], {a:1, b:2, c:3} => ROOT = {a:1, b:2, c:3}
  __set__ = (setters, res) ->
    unless setters then return
    if isArray(setters) and setters.length is 0 then return
    if (not isArray(setters) or not setters.length) and isString(setters)
      setters = [setters]
    setters = formatSetters(setters)
    isArr = isArray(res)
    if not isArr or (setters.length is 1 and isArr) then res = [res]
    if setters.length isnt res.length
      console.error 'ScopeSharer: length is not matched in set function'
    for key, i in setters
      set(key, res[i])

  __debug__ = (debuggers) ->
    unless OPTS.debug then return
    unless isArray debuggers then return
    debuggers.forEach (debug) ->
      obj = get debug.replace('?', '$')
      console.log debug, obj

  get = (str) ->
    str = str
      .replace(/\s+|\$|\{|\}/g, '')
      .replace(/\[[^\[\]]+\]/g, (match)->
        return '.'+match.replace(/\[|\]/g, '')
      )
    getters = str.split('.')
    res = ROOT
    while (getter = getters.shift()) and res
      res = res[getter]
    return res

  set = (setStr, val) ->
    isC = false
    if ~setStr.indexOf '{'
      keys = setStr.replace(/\s+|\{|\}/g, '').split(',')
      isC = true
    else
      keys = [setStr]
    for key in keys
      setters = key.split('.')
      obj = ROOT
      while setter = setters.shift()
        if setters.length
          obj = obj[setter] or= {}
        else
          obj[setter] = if isC then val[setter] else val

  formatSetters = (arr) ->
    res = []
    for str in arr
      res = res.concat format(str)
    return res
  # '[a, b, c]' => ['a', 'b', 'c']
  format = (str) ->
    if str.charAt(0) is '>'
      str = str.slice(1)
    if ~str.indexOf('[')
      return str.replace(/\s+|\[|\]/g, '').split(',')
    else
      return [str]

  handle = (func) ->
    return unless func
    context = null
    # case [fn, context]
    if isArray(func)
      [ func, context ] = func
    if isMiddleware(func) then return handleMW(func)
    args = [].slice.call(arguments, 1)
    len = args.length
    lastArg = args[len-1]
    # handle err msg
    errHandler = null
    if isErrmsg(lastArg)
      errHandler = args.pop()
    # group setters
    [getters, setters, debuggers] = analysis(args)

    return (req, res, next) ->
      [ func, context ] = [ func, context ].map (arg) ->
        return if isString(arg) then __get__(arg) else arg
      callArgs = getters.map (getter) -> 
        return __get__ _.clone(getter)
      # callback
      callArgs.push (err, rlts) ->
        if err
          countStack(err, rlts)
          next(if errHandler then errHandler else err)
        else
          __set__(setters, rlts)
          __debug__(debuggers) if OPTS.debug
          countStack(err, rlts)
          next()
      func.apply(context, callArgs)

  reset = (obj) ->
    ROOT = obj
    stackCounter = 0

  countStack = (err, res) ->
    return unless OPTS.debug
    stackCounter++;
    console.log "stack index: #{stackCounter}, err: #{err}"
    if err
      console.log err

  handleMW = (func) ->
    return (req, res, next) ->
      args = [].slice.call(arguments)
      args.push epts
      func.apply(null, args)

  handleAll = (arr, name) ->
    arr.map (a) ->
      method = if isArray(a) then 'apply' else 'call'
      return handle[method](null, a)

  handleAll(FNS)

  epts =
    get: __get__
    set: __set__
    reset: reset
    handle: handle
    handleAll: handleAll

  return epts

module.exports = ScopeSharer
