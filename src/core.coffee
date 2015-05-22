_ = require('lodash')
u = require('./util')

{ isArray, isString, isObject, isUndefined } = _
{ slice } = u
isErrHandler = (handler) ->
  handler.isErrHandler
isSetter = (str) ->
  isString(str) and /^\>/.test(str)
isDebugger = (str) ->
  isString(str) and /^\?/.test(str)

ScopeSharer = (opts) ->
  opts or= {}
  ROOT = opts.root or {}
  isErrHandler = opts.isErrHandler or isErrHandler

  scope = 
    catch: (err, handler) ->

    handle: (func) ->
      callback(err, res)
      ->
        context = @
        args = slice(arguments)
        callback = args.pop()
        # group getters, setters and debuggers
        [getters, setters, debuggers] = analysis(args)
        callArgs = getters.map __get__
        callArgs.push (err, rlts) ->
          if err
            callback(err)
          else
            __set__(setters, rlts)
            __debug__(debuggers) if opts.debug
            callback(err, rlts)
        func.apply(context, callArgs)

  # group arguments to setters, debuggers and getters
  analysis = (arr) ->
    [ getters, setters, debuggers ] = [ [], [], [] ]
    if isArray(arr)
      switchArr = [
          'case': isSetter
          'when': setters
        ,
          'case': isDebugger
          'when': debuggers
        ,
          'else': getters
      ]
      u.filterFill arr, switchArr
    return [ getters, setters, debuggers ]

  # '$task.name' => ROOT.task.name
  __get__ = (str) ->
    GetReg = /^\$[\w\.]+|\$\{[\w\.]+\}|\$[\w\.]+$/g
    if isString(str)
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
    unless opts.debug then return
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

  return scope

module.exports = ScopeSharer
