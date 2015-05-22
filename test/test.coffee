ScopeSharer = require('../src/core')
Promise = require('bluebird')
fs = require 'fs'

scope = ScopeSharer(
  root: 
    dir: 'test/data.json'
)

delay5 = (a, b, callback) ->
  console.log a, b  
  setTimeout(-> 
    callback(null, a+b)
  , 500)

readFile = scope.handle(fs.readFile)
writeFile = scope.handle(fs.writeFile)
readFile = Promise.promisify readFile

readFile('$dir', 'utf8')
  .then((res)->
    console.log res
  , (err) ->
    console.log err
  )