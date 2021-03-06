(function() {
  var DerivedList, FlattenedList, List, util,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  List = require('./list').List;

  DerivedList = require('./list').DerivedList;

  util = require('../util/util');

  FlattenedList = (function(_super) {
    __extends(FlattenedList, _super);

    function FlattenedList(source, options) {
      var idx, list, _i, _len, _ref,
        _this = this;

      this.source = source;
      this.options = options != null ? options : {};
      FlattenedList.__super__.constructor.call(this);
      this._listListeners = new List();
      this.source.on('removed', function(list, idx) {
        return _this._removeList(list, idx);
      });
      this.source.on('added', function(list, idx) {
        return _this._addList(list, idx);
      });
      _ref = this.source.list;
      for (idx = _i = 0, _len = _ref.length; _i < _len; idx = ++_i) {
        list = _ref[idx];
        this._addList(list, idx);
      }
    }

    FlattenedList.prototype._getOverallIdx = function(list, offset) {
      var listIdx;

      if (offset == null) {
        offset = 0;
      }
      listIdx = this.source.list.indexOf(list);
      return util.foldLeft(0)(this.source.list.slice(0, listIdx), function(length, list) {
        return length + list.list.length;
      }) + offset;
    };

    FlattenedList.prototype._addList = function(list, idx) {
      var elem, event, handler, listeners, _i, _len, _ref, _results,
        _this = this;

      listeners = {
        added: function(elem, idx) {
          return _this._add(elem, _this._getOverallIdx(list, idx));
        },
        removed: function(_, idx) {
          return _this._removeAt(_this._getOverallIdx(list, idx));
        }
      };
      for (event in listeners) {
        handler = listeners[event];
        list.on(event, handler);
      }
      this._listListeners.add(listeners, idx);
      _ref = list.list;
      _results = [];
      for (idx = _i = 0, _len = _ref.length; _i < _len; idx = ++_i) {
        elem = _ref[idx];
        _results.push(this._add(elem, this._getOverallIdx(list, idx)));
      }
      return _results;
    };

    FlattenedList.prototype._removeList = function(list, idx) {
      var event, handler, listStartIdx, _, _i, _len, _ref, _ref1, _results;

      listStartIdx = this._getOverallIdx(list);
      _ref = list.list;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        _ = _ref[_i];
        this._removeAt(listStartIdx);
      }
      _ref1 = this._listListeners.removeAt(idx);
      _results = [];
      for (event in _ref1) {
        handler = _ref1[event];
        _results.push(list.off(event, handler));
      }
      return _results;
    };

    return FlattenedList;

  })(DerivedList);

  util.extend(module.exports, {
    FlattenedList: FlattenedList
  });

}).call(this);
