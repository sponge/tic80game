// title:  game title
// author: game developer
// desc:   short description
// script: wren

var PLAYER_ID = 255

var DIR_LEFT = 1
var DIR_RIGHT = 2
var DIR_TOP = 3
var DIR_BOTTOM = 4

class Math {
   static max(a, b) { a > b ? a : b }
   static min(a, b) { a < b ? a : b }
   static clamp(min, val, max) { val > max ? max : val < min ? min : val }
}

class Debug {
   static text(key, val) {
      if (!__init) {
         __lines = []
         __init = true
      }
      __lines.add([key, val])
   }

   static draw() {
      var y = 0
      for (line in __lines) {
         Tic.print(line[0], 0, y)
         Tic.print(line[1], 32, y)
         y = y + 8
      }
      __lines.clear()
   }
}

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
               var dir = d < 0 ? DIR_TOP : DIR_BOTTOM
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

   check(ldx, ldy) {
      return [
         _world.tileCollider.queryX(_x, _y, _w, _h, ldx, resolve) - _x,
         _world.tileCollider.queryY(_x, _y, _w, _h, ldy, resolve) - _y,
      ]
   }

   move(ldx, ldy) {
      _x = _world.tileCollider.queryX(_x, _y, _w, _h, ldx, resolve)
      _y = _world.tileCollider.queryY(_x, _y, _w, _h, ldy, resolve)
   }

   think(t){}
   draw(){}
}

class Player is Entity {
   resolve { _resolve }
   
   construct new(world, x, y, w, h) {
      super(world, x, y, w, h)

      _resolve = Fn.new { |side, tile, x, y|
         if (tile == 0) {
            return false
         }

         if (side == DIR_LEFT || side == DIR_RIGHT) {
            dx = 0
         }

         if (side == DIR_TOP || side == DIR_BOTTOM) {
            dy = 0
         }

         return true
      }

      _grounded = true
      _fallingFrames = 0
      _pMeter = 0
      _jumpHeld = false
      _jumpHeldFrames = 0

      _friction = 0.0625
      _accel = 0.046875
      _skidAccel = 0.15625
      _runSpeed = 1.125
      _maxSpeed = 1.5
      _pMeterCapacity = 112
      _gravity = 0.09375
      _earlyJumpFrames = 6
      _lateJumpFrames = 6
      _terminalVelocity = 2
      _jumpHeights = {
          1.5: 2.875,
         1.25: 2.78125,
            1: 2.71875,
         0.75: 2.625,
          0.5: 2.5625,
         0.25: 2.46875,
            0: 2.40625
      }
   }
   

   think(t) {
      var dir = Tic.btn(2) ? -1 : Tic.btn(3) ? 1 : 0
      var jumpPress = Tic.btn(4)
      var speed = 0

      _grounded = check(0, 1)[1] == 0
      dy = _grounded ? 0 : dy + _gravity
      _fallingFrames = _grounded ? 0 : _fallingFrames + 1

      _jumpHeldFrames = jumpPress ? _jumpHeldFrames + 1 : 0
      if (!jumpPress && _jumpHeld) {
         _jumpHeld = false
      }

      if (jumpPress && !_jumpHeld) {
         if ((_grounded && _jumpHeldFrames < _earlyJumpFrames) || (!_grounded && _fallingFrames < _lateJumpFrames)) {
            for (speed in _jumpHeights.keys) {
               if (dx.abs >= speed) {
                  dy = -_jumpHeights[speed]
                  _jumpHeld = true
                  break
               }
            }
         }
      }

      if (dir == 0) {
         if (dx != 0) {
            dx = dx + _friction * (dx > 0 ? -1 : 1)
         }

         if (dx.abs < 0.1) {
            dx = 0
         }
      } else {
         speed = dir*dx > 0 ? _accel : _skidAccel
         dx = dx + speed * dir
      }

       _pMeter = Math.clamp(0, dx.abs >= _runSpeed ? _pMeter + 2 : _pMeter - 1, _pMeterCapacity)

      if (_pMeter == _pMeterCapacity) {
         dx = Math.clamp(-_maxSpeed, dx, _maxSpeed)
      } else {
         dx = Math.clamp(-_runSpeed, dx, _runSpeed)
      }

      dy = Math.min(dy, _terminalVelocity)

      move(dx, dy)

      Debug.text("x", x)
      Debug.text("y", y)
      Debug.text("dx", dx)
      Debug.text("dy", dy)
      Debug.text("spd", speed)
      Debug.text("jmp", _jumpHeldFrames)
      Debug.text("P>>>", _pMeter)
      Debug.text("gnd", _grounded)
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
               _entities.add(Player.new(this, x * 8, y * 8 - 4, 7, 12))

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
      Debug.text("time", time)

      for (ent in _entities) {
         ent.think(_time)
      }
   }

   draw() {
      Tic.map(_level * 30, 0, 30, 17, 0, 0, -1, 1, _remap)

      for (ent in _entities) {
         ent.draw()
      }

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
      Debug.draw()
      //_world.update(1)
   }
}