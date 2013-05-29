util = require('../util/util')
Base = require('../core/base').Base
{ Monitor, ComboMonitor } = require('../core/monitor')


class Binder extends Base
  constructor: (@dom, @options) ->
    super()

    this._children = {}
    this._mutatorIndex = {}
    this._mutators = []


  find: (selector) -> this._children[selector] ?= new Binder(this.dom.find(selector), parent: this)


  classed: (className) -> this._attachMutator(ClassMutator, [ className ])
  classGroup: (classPrefix) -> this._attachMutator(ClassGroupMutator, [ classPrefix ])

  attr: (attrName) -> this._attachMutator(AttrMutator, [ attrName ])
  css: (cssAttr) -> this._attachMutator(CssMutator, [ cssAttr ])

  text: -> this._attachMutator(TextMutator)
  html: -> this._attachMutator(HtmlMutator)

  render: (library, options) -> this._attachMutator(RenderMutator, [ library, options ])
  renderWith: (klass, options) -> this._attachMutator(RenderWithMutator, [ klass, options ])


  apply: (f) -> this._attachMutator(ApplyMutator, [ f ])


  from: (dataObj, dataKey) -> this.text().from(dataObj, dataKey)
  fromMonitor: (func) -> this.text().fromMonitor(func)


  end: -> this.options.parent

  data: (primary, aux) ->
    child.data(primary, aux) for _, child of this._children
    mutator.data(primary, aux) for mutator in this._mutators
    null


  _attachMutator: (klass, param) ->
    identity = klass.identity(param)
    existingMutator = (this._mutatorIndex[klass.name] ?= {})[identity]

    mutator = new klass(this.dom, this, param, existingMutator)
    mutator.destroyWith(this)
    this._mutatorIndex[klass.name][identity] = mutator
    this._mutators.push(mutator)
    mutator


class Mutator extends Base
  constructor: (@dom, @parentBinder, @params, @parentMutator) ->
    super()

    this._data = []
    this._listeners = []
    this._fallback = this._transform = this._value = null

    this._parentMutator?._isParent = true

    this._namedParams?(this.params)
    this._initialize?()

  from: (path...) ->
    this._data.push((primary) => this._from(primary, path))
    this

  fromAux: (key, path...) ->
    this._data.push((_, aux) => this._from(util.deepGet(aux, key), path))
    this

  fromAttribute: (key) ->
    this._data.push((primary) -> new Monitor ( value: primary.attribute(key) ))
    this

  _from: (obj, path) ->
    next = (idx) -> (result) ->
      if path[idx + 1]?
        result?.monitor(path[idx], next(idx + 1))
      else
        result?.monitor(path[idx])

    next(0)(obj)

  fromMonitor: (monitorGenerator) ->
    this._data.push((primary, aux) -> monitorGenerator(primary, aux))
    this

  and: this.prototype.from
  andAux: this.prototype.fromAux
  andMonitor: this.prototype.fromMonitor

  andLast: ->
    this._data.push =>
      this.parentMutator.data(primary, aux)
      this.parentMutator._monitor

    this

  transform: (transform) ->
    this._transform = transform
    this

  fallback: (fallback) ->
    this._fallback = fallback
    this


  data: (primary, aux) ->
    listener.destroy() for listener in this._listeners
    this._listeners = (datum(primary, aux) for datum in this._data)

    process = (values...) =>
      if this._transform?
        this._transform(values...)
      else if values.length is 1
        values[0]
      else
        values

    this._monitor = new ComboMonitor(this._listeners, process)
    this._monitor.destroyWith(this)
    this._monitor.on('changed', => this.apply())

    this.apply() unless this.parentBinder.options.bindOnly is true

    this

  calculate: -> this._monitor?.value ? this._fallback
  apply: -> this._apply(this.calculate()) unless this._isParent

  end: -> this.parentBinder

  @identity: -> util.uniqueId()

  _apply: ->

traverseFrom = (obj, path, transform) ->

class ClassMutator extends Mutator
  @identity: ([ className ]) -> className
  _namedParams: ([ @className ]) ->
  _apply: (bool) -> this.dom.toggleClass(this.className, bool ? false)

class ClassGroupMutator extends Mutator
  @identity: ([ classPrefix ]) -> classPrefix
  _namedParams: ([ @classPrefix ]) ->
  _apply: (value) ->
    existingClasses = this.dom.attr('class')?.split(' ')
    if existingClasses?
      this.dom.removeClass(className) for className in existingClasses when className.indexOf(this.classPrefix) is 0
    this.dom.addClass("#{this.classPrefix}#{value}") if value?

class AttrMutator extends Mutator
  @identity: ([ attr ]) -> attr
  _namedParams: ([ @attr ]) ->
  _apply: (value) -> this.dom.attr(this.attr, value)

class CssMutator extends Mutator
  @identity: ([ cssAttr ]) -> cssAttr
  _namedParams: ([ @cssAttr ]) ->
  _apply: (value) -> this.dom.css(this.cssAttr, value) # todo: maybe prefix

class TextMutator extends Mutator
  @identity: -> 'text'
  _apply: (text) -> this.dom.text(text?.toString() ? '')

class HtmlMutator extends Mutator
  @identity: -> 'html'
  _apply: (html) -> this.dom.html(html)

class RenderMutator extends Mutator
  _initialize: ->
    options = { constructorOpts: { viewLibrary: this.library, bindOnly: this.parentBinder.options.bindOnly } }
    util.extend(options, this.options)
    this.options = options

  _namedParams: ([ @library, @options ]) ->
  _apply: (model) ->
    this.dom.empty()

    if model?
      subView = this.library.get(model, this.options)
      subView.destroyWith(this)

      this.dom.append(subView.artifact())

class RenderWithMutator extends Mutator
  _namedParams: ([ @klass, @options ]) ->
  _apply: (model) -> this.dom.empty().append(new this.klass(model, this.options))

class ApplyMutator extends Mutator
  _namedParams: ([ @f ]) ->
  _apply: (value) -> this.f(this.dom, value)

util.extend(module.exports,
  Binder: Binder
  Mutator: Mutator

  mutators:
    ClassMutator: ClassMutator
    ClassGroupMutator: ClassGroupMutator
    AttrMutator: AttrMutator
    CssMutator: CssMutator
    TextMutator: TextMutator
    HtmlMutator: HtmlMutator
    RenderMutator: RenderMutator
    RenderWithMutator: RenderWithMutator
    ApplyMutator: ApplyMutator
)


