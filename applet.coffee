require './resize_observer_polyfill'
window.myou_applets = []
window.active_applets = []
window.applets_on_screen = []

window.max_gl_contexts = 8

ensure_max_gl_contexts = (additions=0)->
    next_applets_on_screen = applets_on_screen.length + additions
    next_active_applets = active_applets.length + additions
    if next_applets_on_screen > max_gl_contexts
        console.warn 'There is more myou applets on screen than the number of supported webgl contexts: ' + next_applets_on_screen + '/' + max_gl_contexts
    must_disable_number = Math.max(next_active_applets - max_gl_contexts,0)
    if must_disable_number
        console.log 'We must delete: ' + must_disable_number + '/' + next_active_applets + ' it will leave: ' + (next_active_applets - must_disable_number) + ' active.'
    active_applets.sort (a,b)->
        a.out_of_screen_since - b.out_of_screen_since

    must_disable = active_applets.slice 0, must_disable_number
    for a in active_applets
        if must_disable.length == must_disable_number
            break
        if a.out_of_screen_since < Infinity
            must_disable.push a

    for a in must_disable
        console.log 'Disabled:', a.props.id, a.out_of_screen_since
        active_applets.splice active_applets.indexOf(a), 1
        if not a.props.component
            a.canvas.style.opacity = 0
            a.canvas.style.pointerEvents = 'none'
        else
            a.props.component.hide()
        a.clear_context()

    return


class MyouApplet
    constructor: (@props={})->
        @is_on_screen = false
        @out_of_screen_since = Infinity
        @on_screen_promise = new Promise (resolve, reject)=>
            # this promise resolverd is saved
            # to be resolved on _set_on_screen
            @_resolve_on_screen_promise = resolve
        @init_promise = new Promise (resolve, reject)=>
            @_resolve_init_promise = resolve
        @visible = @props.visible or false

        @canvas = @init_canvas()

        @props.check_is_on_screen =(@props.check_is_on_screen? and @props.check_is_on_screen) or true

        @props.myou_settings
        @myou = null
        @MyouEngine = null
        @_on_screen_callbacks = []
        @_out_of_screen_callbacks = []
        @scroll_timeout = null

    init_canvas: ->
        if not @props.canvas
            canvas = document.createElement 'canvas'
        else
            canvas = @props.canvas

        canvas.id = @props.id or canvas.id
        canvas.className = 'MyouApplet'
        canvas.title = @props.title or canvas.title
        canvas.style.position = canvas.style.position or 'relative'
        canvas.style.height = canvas.style.height or '100%'
        canvas.style.width = canvas.style.width or '100%'

        if not @props.component
            canvas.style.opacity = (@visible and 1) or 0
            style = @props.style
            l = {}
            if style
                for k,v of style when v and not l[k]? and k!='length'
                    canvas.style[k] = v

        return canvas

    clear_context: ->
        pcanvas = @props.canvas
        @props.canvas = null
        new_canvas = @init_canvas()
        if pcanvas?
            @props.canvas = new_canvas

        @cleared = true
        if @myou?
            @myou.render_manager.clear_context()
            @myou.canvas = null
            @myou.root = null
            @myou.canvas_screen.canvas = null
            @myou.vr_screen?.canvas = null

        @canvas.replaceWith new_canvas
        @canvas = new_canvas

    restore_context: ->
        @myou.render_manager.set_canvas @canvas
        @myou.main_loop.add_frame_callback =>
            @myou.update_root_rect()
            @myou.main_loop.add_frame_callback =>
                @myou.canvas_screen.width = 0
                @myou.canvas_screen.resize_to_canvas()

    recreate_canvas: ->
        pcanvas = @props.canvas
        @props.canvas = null
        new_canvas = @init_canvas()
        if pcanvas?
            @props.canvas = new_canvas
        # @myou.render_manager.clear_context()
        @canvas.replaceWith new_canvas
        @myou.render_manager.set_canvas new_canvas
        @canvas = new_canvas

        @myou.main_loop.add_frame_callback =>
            @myou.update_root_rect()
            @myou.main_loop.add_frame_callback =>
                @myou.canvas_screen.width = 0
                @myou.canvas_screen.resize_to_canvas()


    show: =>
        @on_screen_promise.then =>
            @myou.main_loop.add_frame_callback =>
                @props.on_show_applet?()
                @visible = true
                if not @props.component
                    @canvas.style.opacity = 1
                    @canvas.style.pointerEvents = 'all'
                else
                    @props.component.show()

    hide: =>
        @myou.main_loop.add_frame_callback =>
            @props.on_hide_applet()
            @visible = false
            if not @props.component
                @canvas.style.opacity = 0
                @canvas.style.pointerEvents = 'none'
            else
                @props.component.hide()

    stop_on_scroll: =>
        clearTimeout @scroll_timeout
        {myou} = @
        return if not myou
        if @visible
            myou.main_loop.enabled = false
            @scroll_timeout = setTimeout ->
                myou.main_loop.enabled = true
                try
                    myou.update_root_rect()
                catch error
            , 200

    on_update: (new_props={})=>
        removeEventListener 'scroll', @check_is_on_screen
        check = (new_props.check_is_on_screen? and new_props.check_is_on_screen) or @props.check_is_on_screen
        if check
            addEventListener 'scroll', @check_is_on_screen

        if new_props.id
            @canvas.id = new_props.id + '.canvas'
        if @props.component
            applet_container = @props.component.applet_container_ref.current
            if not applet_container.children.length and
                applet_container.children[0] != @canvas
                    applet_container.insertBefore @canvas, applet_container.firstChild
        @check_is_on_screen()

    enable: (new_props)->
        @on_update(new_props)
        @enabled = true
        @resizing = @on_screen_promise.then =>
            @resize_observer = new ResizeObserver(@on_resize)
            @resize_observer.observe @canvas
            @resizing = null
            if not @myou
                if not window._myou_engine_load_promise
                    myou_engine = document.createElement 'script'
                    myou_engine.src = module.exports.myou_js_path
                    document.body.appendChild myou_engine
                    window._myou_engine_load_promise = new Promise (resolve, reject) ->
                        window._myou_engine_loaded_callback = resolve
                promise = window._myou_engine_load_promise
                promise.then (MyouEngine)=>
                    myou = @myou = @myou or new MyouEngine.Myou @canvas, @props.myou_settings
                    myou.MyouEngine = MyouEngine
                    myou.applet = @
                    @props.app? myou
                    myou_applets.push @
                    window.$myou = myou
                    @_resolve_init_promise()

    disable: ->
        @_set_out_of_screen()
        @myou?.main_loop.enabled = false
        @resize_observer?.unobserve(@canvas)
        @resize_observer?.disconnect()
        @resize_observer = null
        @enabled = false

    on_resize: => if not @resizing
        @resizing = @on_screen_promise.then =>
            @myou?.main_loop.add_frame_callback =>
                @myou?.canvas_screen?.resize_to_canvas()
                @resizing = null

    add_on_screen_callback: (c)=>
        if @_on_screen_callbacks.indexOf(c) > -1
            console.warn 'You are trying to add an existing on_screen_callback:\n' + c
            return
        @_on_screen_callbacks.push c

    add_out_of_screen_callback: (c)=>
        if @_out_of_screen_callbacks.indexOf(c) > -1
            console.warn 'You are trying to add an existing out_screen_callback:\n' + c
            return
        @_out_of_screen_callbacks.push c

    remove_on_screen_callback: (c)=>
        index = @_on_screen_callbacks.indexOf(c)
        if index > -1
            @_on_screen_callbacks.splice index, 1

    remove_out_of_screen_callback: (c)=>
        index = @_out_of_screen_callbacks.indexOf(c)
        if index > -1
            @_out_of_screen_callbacks.splice index, 1

    _set_on_screen: -> if not @is_on_screen
        @out_of_screen_since = Infinity
        ensure_max_gl_contexts(1)
        @init_promise.then =>
            if @cleared
                @restore_context()
                setTimeout =>
                    #TODO: Black frames after restoring context
                    if not @props.component
                        @canvas.style.opacity = 1
                        @canvas.style.pointerEvents = 'all'
                    else
                        @props.component.show()
                ,1000
            if @ not in applets_on_screen
                applets_on_screen.push @
            if @ not in active_applets
                active_applets.push @

        for c in @_on_screen_callbacks
            c()
        @_resolve_on_screen_promise()
        if @props.stop_on_scroll
            removeEventListener 'scroll', @stop_on_scroll
            addEventListener 'scroll', @stop_on_scroll
        else
            removeEventListener 'scroll', @stop_on_scroll
        @resize_observer?.observe(@canvas)
        @is_on_screen = true


    _set_out_of_screen: -> if @is_on_screen
        i = applets_on_screen.indexOf(@)
        if i != -1
            applets_on_screen.splice(i, 1)
        for c in @_out_of_screen_callbacks
            c()
        @resize_observer.unobserve(@canvas)
        @on_screen_promise = new Promise (resolve, reject)=>
            # this promise resolverd is saved
            # to be resolved on _set_on_screen
            @_resolve_on_screen_promise = resolve
        @is_on_screen = false
        @out_of_screen_since = performance.now()

    check_is_on_screen: =>
        if not @enabled
            @_set_out_of_screen()
            return false

        rect = @canvas.getBoundingClientRect()
        top = rect.top
        bottom = top + rect.height
        if 0 <= bottom and top <= innerHeight
            @_set_on_screen()
            return true
        else
            @_set_out_of_screen()
            return false

module.exports = {MyouApplet}
