module.exports = require('./build/main.js')
module.exports.myou_js_path = require('file-loader!./build/myou.js')
console.log ('myou_js_path', module.exports.myou_js_path)
