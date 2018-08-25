if not window.ResizeObserver
    console.warn 'Using ResizeObserver polyfill'
    # this code is a port of https://developers.google.com/web/updates/2016/10/resizeobserver
    window.ResizeObserver = class ResizeObserver
        constructor: (@callback)->
            @observables = []
              # Array of observed elements that looks like this:
              # [{
              #   el: domNode,
              #   callback: func,
              #   size: {height: x, width: y}
              # }]
            @check()
        observe: (el, callback) ->
            newObservable =
                el: el
                callback: callback
                size:
                    height: el.clientHeight
                    width: el.clientWidth
            @observables.push newObservable
        unobserve: (el)->
            @observables = @observables.filter (obj)=> obj.el != el
        disconnect: ->
            @isPaused = false
        check: =>
            @observables.map (obj)=>
                currentHeight = obj.el.clientHeight
                currentWidth = obj.el.clientWidth
                if (obj.size.height != currentHeight) or (obj.size.width != currentWidth)
                    @callback(obj.el)
                    obj.size.height = currentHeight
                    obj.size.width = currentWidth
                return obj

            if not @isPaused
                requestAnimationFrame @check
