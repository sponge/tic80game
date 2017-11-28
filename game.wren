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
      var right = x+w+d
      right = right == right.floor ? right - 1 : right
      var gx2 = d >= 0 ? (right / ts).floor : ((x+d) / ts).floor
      //Debug.text("gtr", "%(x) %(w) %(d) %(gx..gx2)")

      return gx..gx2
   }

   queryX(x, y, w, h, d, resolveFn) {
      var origPos = x + d
      var xRange = getTileRange(_tw, x, w, d)
      var yRange = getTileRange(_th, y, h, 0)

      for (tx in xRange) {
         for (ty in yRange) {
            Tic.rectb(tx*8, ty*8, 8, 8, 4)
            var tile = _getTile.call(tx, ty)
            if (tile > 0) {
               var dir = d < 0 ? DIR_LEFT : DIR_RIGHT
               if (resolveFn.call(dir, tile, tx, ty) == true) {
                  Tic.rectb(tx*8, ty*8, 8, 8, 8)
                  var check = origPos..(tx + (d >= 0 ? 0 : 1)) *_tw - (d >= 0 ? w : 0)
                  return d < 0 ? check.max : check.min
               }
            }
         }
      }

      return origPos
   }

   queryY(x, y, w, h, d, resolveFn) {
      var origPos = y + d
      var xRange = getTileRange(_tw, x, w, 0)
      var yRange = getTileRange(_th, y, h, d)

      for (ty in yRange) {
         for (tx in xRange) {
            Tic.rectb(tx*8, ty*8, 8, 8, 4)
            var tile = _getTile.call(tx, ty)
            if (tile > 0) {
               var dir = d < 0 ? DIR_TOP : DIR_BOTTOM
               if (resolveFn.call(dir, tile, tx, ty) == true) {
                  Tic.rectb(tx*8, ty*8, 8, 8, 8)
                  var check = origPos..(ty + (d >= 0 ? 0 : 1)) *_th - (d >= 0 ? h : 0)
                  return d < 0 ? check.max : check.min
               }
            }
         }
      }

      return origPos
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
   
   construct new(world, ox, oy, ow, oh) {
      super(world, ox, oy, ow, oh)

      _resolve = Fn.new { |side, tile, tx, ty|
         if (tile == 0) {
            return false
         }

         if (tile == 4) {
            //Debug.text("plat", "%(ty), %(side == DIR_BOTTOM) && %(y+h) <= %(ty*8) && %(y+h+dy) > %(ty*8)")
            var platform = side == DIR_BOTTOM && y+h <= ty*8 && y+h+dy > ty*8
            if (platform) {
               _grounded = true
            }

            return platform
         }


         if (side == DIR_LEFT || side == DIR_RIGHT) {
            dx = 0
         }

         if (side == DIR_TOP) {
            dy = 0
         }

         if (side == DIR_BOTTOM) {
            _grounded = true
         }

         return true
      }

      _grounded = true
      _fallingFrames = 0
      _pMeter = 0
      _jumpHeld = false
      _jumpHeldFrames = 0

      _friction = 0.03125
      _accel = 0.046875
      _skidAccel = 0.15625
      _runSpeed = 1.125
      _maxSpeed = 1.5
      _pMeterCapacity = 112
      _heldGravity = 0.09375
      _gravity = 0.1875
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

      // track if on the ground this frame, and track frames since leaving platform for late jump presses
      _grounded = check(0, 1)[1] == 0
      _fallingFrames = _grounded ? 0 : _fallingFrames + 1

      // let players jump a few frames early but don't let them hold the button down
      _jumpHeldFrames = jumpPress ? _jumpHeldFrames + 1 : 0
      if (!jumpPress && _jumpHeld) {
         _jumpHeld = false
      }

      // apply gravity if not on the ground. different gravity values depending on holding jump
      dy = _grounded ? 0 : dy + (_jumpHeld ? _heldGravity : _gravity)

      // if jump is held, and player has let go of it since last jump
      if (jumpPress && !_jumpHeld) {
         // allow the jump if:
         // - they're on the ground, and haven't been holding for too long
         // - they're not on the ground, but have recently been on the ground
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

      // if not pushing anything, slow down if on the ground
      if (dir == 0) {
         if (dx != 0 && _grounded) {
            dx = dx + _friction * (dx > 0 ? -1 : 1)
         }

         // null out small values so we dont keep bouncing around 0
         if (dx.abs <= _friction) {
            dx = 0
         }
      // if holding a direction, figure out how fast we should try and go
      } else {
         speed = dir*dx > 0 ? _accel : _skidAccel
         dx = dx + speed * dir
      }

      // increment the p-meter if you're on the ground and going fast enough
      if (dx.abs >= _runSpeed && _grounded) {
         _pMeter = _pMeter + 2
      // tick down the p-meter, but don't if you're at 100% and midair
      } else {
         if (_grounded || _pMeter != _pMeterCapacity) {
            _pMeter = _pMeter - 1
         }
      }
      _pMeter = Math.clamp(0, _pMeter, _pMeterCapacity)

      // hard cap speed values
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
      Debug.text("P>>>", "%((_pMeter/_pMeterCapacity * 100).floor)\%")
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
         if (x < 0 || x > 29) {
            return 1
         }
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
      _slomo = false
   }
   
   update(){
      if (Tic.btnp(7, 1, 60)) {
         _slomo = !_slomo
      }

      if (!_slomo || Tic.btnp(6, 1, 30)) {
         Tic.cls()
         _world.update(1)
         _world.draw()
         Debug.draw()
      }
   }
}