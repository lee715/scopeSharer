_ = require 'lodash'
u = require '../src/util'

console.log u.pickVals {a:1, b:2}, 'a', 'c'

rs = 
  a: []
  b: []
  c: []

u.filterFill 'qwertyuiopasdfghjklzxcvbnm'.split(''),
  [
    'case': '/a|b|c/'
    'when': rs.a
  ,
    'case': (i) -> i > 'd' and i < 'y'
    'when': rs.b
  ,
    'else': rs.c
  ]

console.log rs