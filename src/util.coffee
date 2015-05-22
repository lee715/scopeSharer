_ = require 'lodash'

isRegExpStr = (str) -> /^\/\S+\/[igm]{0,2}$/.test(str.toString?())

returnSelf = (self) -> self

slice = (arr) ->
  args = [].slice.call(arguments, 1)
  [].slice.apply(arr, args)

push = (arr, item) ->
  arr.push(item)

toBoolean = (obj) ->
  return !!obj

regExp2Str = (reg) ->
  if _.isString(reg) then reg.toString().replace(/^\/|\/$/g, '') else ''

u = util = 

  isRegExpStr: isRegExpStr

  toRegExp: (str) ->
    if _.isString(str) then new RegExp(regExp2Str(str)) else false

  slice: slice

  push: push

  pickVals: ->
    args = slice(arguments, 1)
    obj = _.pick.apply _, arguments
    args.map _.propertyOf(obj)

  ensureCaseHdl: (caseHdl) ->
    # 如果caseHdl为字符串，返回函数判断匹配或包含
    if _.isString caseHdl
      reg = u.toRegExp caseHdl
      return _.partial u.test, reg
    else if _.isFunction caseHdl
      return caseHdl
    else if caseHdl
      return _.partial _.isEqual, caseHdl
    else
      return toBoolean

  ensureWhenHdl: (whenHdl) ->
    if _.isArray(whenHdl)
      return _.partial push, whenHdl
    else if _.isFunction(whenHdl)
      return whenHdl
    else
      return returnSelf

  test: (regExp, str) ->
    regExp.test? str

  arg2objWrap: (func) ->
    args = slice(arguments, 1)
    len = args.length
    ->
      obj = arguments[0]
      wrappedArgs = u.pickVals.apply _, [obj].concat(args)
      callArgs = wrappedArgs.concat slice(arguments, 1)
      func.apply(@, callArgs) 

  caseWhen: (caseHdl, whenHdl, elseHdl, item) ->
    if _.isUndefined(elseHdl)
      caseHdl = u.ensureCaseHdl(caseHdl)
      whenHdl = u.ensureWhenHdl(whenHdl)
      return if caseHdl(item) then whenHdl(item) else false
    else
      elseHdl = u.ensureWhenHdl(elseHdl)
      return elseHdl(item)

  switchWhen: (caseArr, item) ->
    caseWhen = u.arg2objWrap u.caseWhen, 'case', 'when', 'else'
    wrappedCaseWhen = u.mapWrap caseArr, caseWhen
    wrappedCaseWhen(item)

  switchUntil: (caseArr, item) ->
    caseWhen = u.arg2objWrap u.caseWhen, 'case', 'when', 'else'
    wrappedCaseWhen = u.untilWrap caseArr, caseWhen
    wrappedCaseWhen(item)

  filterFill: (arr, caseArr) ->
    arr.filter _.partial u.switchUntil, caseArr

  mapFill: (arr, caseArr) ->
    arr.map _.partial u.switchWhen, caseArr

  mapWrap: (arr, func) ->
    ->
      args = slice(arguments)
      arr.map (item) ->
        _args = [item].concat args
        func.apply(null, _args)

  untilWrap: (arr, func) ->
    ->
      args = slice(arguments)
      for item in arr
        _args = [item].concat args
        res = func.apply(null, _args)
        return res if res
      return false
         

module.exports = util