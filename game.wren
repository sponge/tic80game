// title:  game title
// author: game developer
// desc:   short description
// script: wren

var PLAYER_ID = 255

var DIR_LEFT = 1
var DIR_RIGHT = 2
var DIR_UP = 3
var DIR_DOWN = 4

class TileCollider {
   construct new(getTile, tileWidth, tileHeight) {
      _tw = tileWidth
      _th = tileHeight
      _getTile = getTile
   }

   getTileRange(ts, x, w, d) {
      var gx = (x / ts).floor
      var gx2 = d >= 0 ? ((x+w+d-1) / ts).floor : ((x+d-1) / ts).floor
      return gx..gx2
   }

   queryX(x, y, w, h, d, resolveFn) {
      var newPos = x + d
      var origPos = x + d
      var xRange = getTileRange(_tw, x, w, d)
      var yRange = getTileRange(_th, y, h, 0)

      for (tx in xRange) {
         for (ty in yRange) {
            //Tic.rectb(tx*8, ty*8, 8, 8, 4)
            var tile = _getTile.call(tx, ty)
            if (tile > 0) {
               var dir = d < 0 ? DIR_LEFT : DIR_RIGHT
               if (resolveFn.call(dir, tile, tx, ty) == true) {
                  //Tic.rectb(tx*8, ty*8, 8, 8, 8)
                  var check = newPos..(tx + (d >= 0 ? 0 : 1)) *_tw - (d >= 0 ? w : 0)
                  newPos = d < 0 ? check.max : check.min
               }
            }
         }

         if (newPos != origPos) {
            break
         }
      }

      //Tic.rectb(newPos, y, w, h, 6)
      return newPos
   }

   queryY(x, y, w, h, d, resolveFn) {
      var newPos = y + d
      var origPos = y + d
      var xRange = getTileRange(_tw, x, w, 0)
      var yRange = getTileRange(_th, y, h, d)

      for (ty in yRange) {
         for (tx in xRange) {
            //Tic.rectb(tx*8, ty*8, 8, 8, 4)
            var tile = _getTile.call(tx, ty)
            if (tile > 0) {
               var dir = d < 0 ? DIR_UP : DIR_DOWN
               if (resolveFn.call(dir, tile, tx, ty) == true) {
                  //Tic.rectb(tx*8, ty*8, 8, 8, 8)
                  var check = newPos..(ty + (d >= 0 ? 0 : 1)) *_th - (d >= 0 ? h : 0)
                  newPos = d < 0 ? check.max : check.min
               }
            }
         }

         if (newPos != origPos) {
            break
         }
      }

      //Tic.rectb(x, newPos, w, h, 6)
      return newPos
   }
}

class Entity {
   x { _x }
   x=(x) { _x = x }
   y { _y }
   y=(y) { _y = y }
   w { _w }
   w=(w) { _w = w }
   h { _h }
   h=(h) { _h = h }
   dx { _dx }
   dx=(dx) { _dx = dx }
   dy { _dy }
   dy=(dy) { _dy = dy }
   
   construct new(world, x, y, w, h) {
      _world = world
      _x = x
      _y = y
      _w = w
      _h = h
      _dx = 0
      _dy = 0
   }

   move() {
      _x = _world.tileCollider.queryX(_x, _y, _w, _h, _dx, resolve)
      _y = _world.tileCollider.queryY(_x, _y, _w, _h, _dy, resolve)
   }

   think(t){}
   draw(){}
}

class Player is Entity {
   resolve { _resolve }
   
   construct new(world, x, y, w, h) {
      super(world, x, y, w, h)

      _resolve = Fn.new { |side, tile, x, y|
         return tile > 0
      }
   }

   think(t) {
      dx = Tic.btn(2) ? -1 : Tic.btn(3) ? 1 : 0
      dy = Tic.btn(0) ? -1 : Tic.btn(1) ? 1 : 0
      move()
   }

   draw() {
      Tic.rect(x, y, w, h, 14)
   }
}

class World {
   time { _time }
   tileCollider { _tileCollider }

   construct new() {
      _entities = []
      _time = 0
      _level = 0
      _spawned = false

      _remap = Fn.new { |i, x, y|
         if (_spawned == false) {
            if (i == PLAYER_ID) {
               _entities.add(Player.new(this, x * 8, y * 8 - 2, 7, 10))

               _spawned = true
            }
         }

         if (i > 200) {
            return 0
         }
         return i
      }

      _getTile = Fn.new { |x, y|
         var t = Tic.mget(x,y)
         t = t > 200 ? 0 : t

         return t
      }

      _tileCollider = TileCollider.new(_getTile, 8, 8)

   }

   update(t) {
      _time = _time + t

      for (ent in _entities) {
         ent.think(_time)
      }
   }

   draw() {
      Tic.map(_level * 30, 0, 30, 17, 0, 0, -1, 1, _remap)

      for (ent in _entities) {
         ent.draw()
      }

      Tic.print(time, 1, 1)
   }
}

class Game is Engine {
   construct new(){
      _t=0
      _world = World.new()
   }
   
   update(){
      Tic.cls()
      _world.update(1)
      _world.draw()
   }
}