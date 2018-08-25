'use strict'
var webpack = require('webpack');
var path = require('path')
// generating banner
var fs = require('fs');
var license = fs.readFileSync('./LICENSE', 'utf8').toString()

var config = {
    output: {
        path: __dirname + '/build',
        filename: '[name].js',
        publicPath: "/build/",
        library: "[name]_library, m = (typeof module === 'undefined' ? {} : module);var [name]_library = m.exports",
    },
    context: __dirname,
    entry: {
        main: __dirname + '/main.coffee',
        myou: __dirname + '/myou.coffee',
    },
    stats: {
        colors: true,
        reasons: true
    },
    module: {
        rules: [
            {
                test: /\.coffee$/,
                use: {
                    loader: 'coffee-loader',
                },
            },
        ]
    },
    plugins: [
        new webpack.BannerPlugin({banner:license, raw:false}),
        new webpack.IgnorePlugin(/^(fs|stylus|path|coffeescript)$/),
        new webpack.DefinePlugin({
            'process.env': {
                'NODE_ENV': '"production"'
            },
        }),
    ],
    resolve: {
        extensions: [".webpack.js", ".web.js", ".js", ".coffee"],
        alias: {
            // You can use this to override some packages and use local versions
            // 'myou-engine': path.resolve(__dirname+'/node_modules/myou-engine/pack.coffee'),
            'myou-engine': path.resolve(__dirname+'/../myou-engine/pack.coffee'),
        },
    },
}
module.exports = config
