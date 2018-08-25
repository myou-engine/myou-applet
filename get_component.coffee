{MyouApplet} = require './applet'
module.exports = (React)->
    e = React.createElement
    myou_applets = {}

    clone = (obj) ->
      if not obj? or typeof obj isnt 'object'
        return obj
      if obj instanceof Date
        return new Date(obj.getTime())
      if obj instanceof RegExp
        flags = ''
        flags += 'g' if obj.global?
        flags += 'i' if obj.ignoreCase?
        flags += 'm' if obj.multiline?
        flags += 'y' if obj.sticky?
        return new RegExp(obj.source, flags)
      newInstance = new obj.constructor()
      for key of obj
        newInstance[key] = clone obj[key]
      return newInstance

    return class MyouAppletComponent extends React.Component
        constructor: (props={})->
            applet_props = clone props
            super props
            applet_props.component = @

            @state = {visible:false}

            @applet = myou_applets[props.id]
            if not @applet
                @applet = new MyouApplet applet_props
            else
                @applet.props = applet_props
                @state.visible = @applet.visible

            @applet_container_ref = React.createRef()
            myou_applets[props.id] = @applet

        show: =>
            @setState {visible:true}

        hide: =>
            @setState {visible:false}

        componentDidUpdate: ->
            @applet.on_update(@props)

        componentDidMount: ->
            requestAnimationFrame => @applet.enable(@props)

        componentWillUnmount: ->
            @applet.disable()

        render: ->
            e 'div',
                id: @props.id + '.container'
                className: 'MyouAppletContainer'
                ref: @applet_container_ref
                style: Object.assign {}, {
                        position: 'relative'
                        height: '100%'
                        width: '100%'
                        opacity: (@state.visible and 1) or 0
                    },
                    @props.style
                @props.children
