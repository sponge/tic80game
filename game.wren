// title:  game title
// author: game developer
// desc:   short description
// script: wren

var DIR_LEFT = 1
var DIR_RIGHT = 2
var DIR_TOP = 4
var DIR_BOTTOM = 8

class Math {
   static sign(a) { a < 0 ? -1 : 1 }
   static max(a, b) { a > b ? a : b }
   static min(a, b) { a < b ? a : b }
   static clamp(min, val, max) { val > max ? max : val < min ? min : val }
}

class Debug {
   static text(val) {
      text(val, "")
   }

   static rectb(x, y, w, h, c) {
      __rectbs.add([x, y, w, h, c])
   }

   static rect(x, y, w, h, c) {
      __rects.add([x, y, w, h, c])
   }

   static init() {
      __lines = []
      __rectbs = []
      __rects = []
   }

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

      for (r in __rectbs) {
         Tic.rectb(r[0], r[1], r[2], r[3], r[4])
      }

      for (r in __rects) {
         Tic.rect(r[0], r[1], r[2], r[3], r[4])         
      }
      
      __lines.clear()
      __rectbs.clear()
      __rects.clear()
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
            //Debug.rectb(tx*8, ty*8, 8, 8, 4)
            var tile = _getTile.call(tx, ty)
            if (tile > 0) {
               var dir = d < 0 ? DIR_LEFT : DIR_RIGHT
               if (resolveFn.call(dir, tile, tx, ty, d, 0) == true) {
                  //Debug.rectb(tx*8, ty*8, 8, 8, 8)
                  var check = origPos..(tx + (d >= 0 ? 0 : 1)) *_tw - (d >= 0 ? w : 0)
                  return (d < 0 ? check.max : check.min) - x
               }
            }
         }
      }

      return d
   }

   queryY(x, y, w, h, d, resolveFn) {
      var origPos = y + d
      var xRange = getTileRange(_tw, x, w, 0)
      var yRange = getTileRange(_th, y, h, d)

      for (ty in yRange) {
         for (tx in xRange) {
            //Debug.rectb(tx*8, ty*8, 8, 8, 4)
            var tile = _getTile.call(tx, ty)
            if (tile > 0) {
               var dir = d < 0 ? DIR_TOP : DIR_BOTTOM
               if (resolveFn.call(dir, tile, tx, ty, 0, d) == true) {
                  //Debug.rectb(tx*8, ty*8, 8, 8, 8)
                  var check = origPos..(ty + (d >= 0 ? 0 : 1)) *_th - (d >= 0 ? h : 0)
                  return (d < 0 ? check.max : check.min) - y
               }
            }
         }
      }

      return d
   }
}

class Collision {
   delta { _delta }
   entity { _entity }
   entity=(e) { _entity = e }
   side { _side }

   construct new(delta, entity, side) {
      update(delta, entity, side)
   }

   update(delta, entity, side) {
      _delta = delta
      _entity = entity
      _side = side

      return this
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

   world { _world }

   xCollide { _xCollide }
   yCollide { _yCollide }
   
   construct new(world, x, y, w, h) {
      _world = world
      _x = x
      _y = y - (8 - h)
      _w = w
      _h = h
      _dx = 0
      _dy = 0

      _xCollide = Collision.new(0, null, 0)
      _yCollide = Collision.new(0, null, 0)
   }

   collide(other, ldx, ldy) {
      var ox = this.x + (this.w / 2) + ldx - other.x - (other.w / 2)
      var px = (this.w / 2) + (other.w / 2) - ox.abs

      if (px <= 0) {
         return ldx != 0 ? ldx : ldy
      }
      
      var oy = this.y + (this.h / 2) + ldy - other.y - (other.h / 2)
      var py = (this.h / 2) + (other.h / 2) - oy.abs

      if (py <= 0) {
         return ldx != 0 ? ldx : ldy
      }

      if (ldx != 0) {
         var rx = ldx + px * Math.sign(ox)
         return rx 
      } else {
         var ry = ldy + py * Math.sign(oy)
         return ry
      }
   }

   checkX(ldx) {
      var dir = ldx > 0 ? DIR_RIGHT : DIR_LEFT
      var newX = _world.tileCollider.queryX(_x, _y, _w, _h, ldx, resolve)
      var collideEnt = null

      for (ent in _world.entities) {
         if (ent != this && ent.w > 0 && ent.h > 0) {
            var tempX = this.collide(ent, newX, 0)
            if (tempX != newX) {
               collideEnt = ent
            }

            if (ent.canCollide(this, dir)) {
               newX = ldx > 0 ? Math.min(newX, tempX) : Math.max(newX, tempX)
            }
         }
      }

      return _xCollide.update(newX, collideEnt, dir)
   }

   checkY(ldy) {
      var dir = ldy < 0 ? DIR_TOP : DIR_BOTTOM
      var newY = _world.tileCollider.queryY(_x, _y, _w, _h, ldy, resolve)
      var collideEnt = null

      for (ent in _world.entities) {
         if (ent != this && ent.w > 0 && ent.h > 0) {
            var tempY = this.collide(ent, 0, newY)
            if (tempY != newY) {
               collideEnt = ent
            }

            if (ent.canCollide(this, dir)) {
               newY = ldy > 0 ? Math.min(newY, tempY) : Math.max(newY, tempY)
            }
         }
      }

      return _yCollide.update(newY, collideEnt, dir)
   }

   canCollide(other, side){ true }
   touch(other, side){}
   think(t){}
   draw(){}
}

class LevelExit is Entity {
   construct new(world, ox, oy) {
      super(world, ox, oy, 8, 8)
   }

   canCollide(other, side){ true }

   draw() {
      var c = world.cam.toCamera(x, y)
      Tic.spr(254, c[0], c[1])
   }
}

class Player is Entity {
   resolve { _resolve }
   
   construct new(world, ox, oy) {
      super(world, ox, oy, 7, 12)

      _resolve = Fn.new { |side, tile, tx, ty, ldx, ldy|
         if (tile == 0) {
            return false
         }

         if (tile >= 240) {
            // editor only item
            return false
         }

         if (tile == 4) {
            //Debug.text("plat", "%(ty), %(side == DIR_BOTTOM) && %(y+h) <= %(ty*8) && %(y+h+ldy) > %(ty*8)")
            return side == DIR_BOTTOM && y+h <= ty*8 && y+h+ldy > ty*8
         }

         return true
      }

      _grounded = true
      _fallingFrames = 0
      _pMeter = 0
      _jumpHeld = false
      _jumpHeldFrames = 0
      _groundEnt = null

      // values from https://cdn.discordapp.com/attachments/191015116655951872/332350193540268033/smw_physics.png
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
      var grav = checkY(1)
      _grounded = grav.delta == 0
      _fallingFrames = _grounded ? 0 : _fallingFrames + 1
      _groundEnt = grav.entity

      //Debug.text("grnd", grav.entity)

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
         speed = Math.sign(dir*dx) == -1 ? _skidAccel : _accel
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

      // move x first, then move y. don't do it at the same time, else buggy behavior
      var chkx = checkX(dx)
      x = x + chkx.delta
      var chky = checkY(dy)
      y = y + chky.delta

      //Debug.text("entx", chkx.entity)
      //Debug.text("enty", chky.entity)

      // if we hit either direction in x, stop momentum
      if (chkx.delta != dx) {
         dx = 0
      }

      if (chky.delta != dy) {
         // if we're falling down, we've hit the ground
         if (dy > 0) {
            _grounded = true
         }
         // either dir, nullify y movement
         dy = 0
      }

      // update camera
      world.cam.window(x, y, 20)

      // Debug.text("x", x)
      // Debug.text("y", y)
      // Debug.text("dx", dx)
      // Debug.text("dy", dy)
      // Debug.text("spd", speed)
      // Debug.text("jmp", _jumpHeldFrames)
      // Debug.text("gnd", _grounded)
      Debug.text("P>>>", "%((_pMeter/_pMeterCapacity * 100).floor)\%")

   }

   draw() {
      var c = world.cam.toCamera(x, y)
      Tic.rect(c[0], c[1], w, h, 14)
   }
}

class Camera {
   x { _x }
   y { _y }
   tx { _txRange.min }
   ty { _tyRange.min }
   tw { _txRange.max - _txRange.min }
   th { _tyRange.max - _tyRange.min }

   construct new(tw, th, w, h) {
      _tw = tw
      _th = th
      _w = w
      _h = h

      _conx = 0
      _cony = 0
      _conw = 0
      _conh = 0

      _x = 0
      _y = 0
      _txRange = 0..30
      _tyRange = 0..17
   }

   constrain(x, y, w, h) {
      _conx = x
      _cony = y
      _conw = w
      _conh = h

      move(_x, _y)
   }

   move(x, y) {
      _x = x.floor
      _y = y.floor

      if (_conw > 0 && _conh > 0) {
         //Debug.text("max", "%(_conx) %(_x) %(_conx+_conw-_w)")
         _x = Math.clamp(_conx, _x, _conx+_conw-_w)
         _y = Math.clamp(_cony, _y, _cony+_conh-_h)
      }

      _x = Math.max(_x, 0)
      _y = Math.max(_y, 0)

      //Debug.text("cam", "%(_x) %(_y)")

      var tx = (_x / _tw).floor
      var ty = (_y / _th).floor

      _txRange = tx..tx+(_w/_tw).ceil+1
      _tyRange = ty..ty+(_h/_th).ceil+1 
   }

   window(px, py, windowWidth) {
      var center = _x + _w/2

      if ((px - center).abs <= windowWidth) {
         return
      }

      var delta = px - center + (px > center ? -1 : 1) * windowWidth
      move(_x + delta, y)
   }

   center(x,y) {
      move(x - _w/2, y - _h/2)
   }

   toCamera(px,py) {
      return [px - x, py - y] 
   }

   toWorld(cx, cy) {
      return [cx + x, cy + y]
   }
}

class World {
   time { _time }
   tileCollider { _tileCollider }
   cam { _cam }
   entities { _entities }

   construct new(i) {
      _entities = []
      _time = 0
      _levels = [
         {"x": 0, "y": 0, "w": 43, "h": 17}
      ]
      _level = _levels[i]
      _cam = Camera.new(8, 8, 240, 136)
      _cam.constrain(_level["x"], _level["y"], _level["w"]*8, _level["h"]*8)

      var entmappings = {
         255: Player,
         254: LevelExit
      }

      for (y in _level["y"].._level["y"]+_level["h"]) {
         for (x in _level["x"].._level["x"]+_level["w"]) {
            var i = Tic.mget(x, y)
            var e = entmappings[i]
            if (e != null) {
               _entities.add(e.new(this, x*8, y*8))
            }
         }
      }

      _remap = Fn.new { |i, x, y|
         if (i >= 240) {
            return 0
         }
         return i
      }

      _getTile = Fn.new { |x, y|
         if (x < 0 || x > _level["w"]-1) {
            return 1
         }
         
         var t = Tic.mget(x,y)
         t = t >= 240 ? 0 : t

         return t
      }

      _tileCollider = TileCollider.new(_getTile, 8, 8)

   }

   update(dt) {
      _time = _time + dt
      Debug.text("time", time)

      for (ent in _entities) {
         ent.think(_time)
      }
   }

   draw() {
      Tic.map(_cam.tx, _cam.ty, _cam.tw, _cam.th, 0 - _cam.x % 8, 0 - _cam.y % 8, -1, 1, _remap)

      for (ent in _entities) {
         ent.draw()
      }

   }
}

class Intro {
   construct new(num) {
      _num = num
      _t = 0
   }

   update(dt) {
      _t = _t + dt

      if (_t > 120) {
         Scene.level(_num)
         return
      }
   }

   draw() {
      Tic.cls(2)
      Tic.print("ENTERING LEVEL %(_num+1)", 70, 60)
   }
}

class Scene {
   static intro(num) {
     __world = Intro.new(num)
   }

   static level(num) {
      __world = World.new(num)
   }

   static update(i) {
      __world.update(i)
   }

   static draw() {
      __world.draw()
   }
}

class Game is Engine { 
   construct new(){
      Debug.init()
      _slomo = false
      Scene.level(0)
   }
   
   update(){
      if (Tic.btnp(7, 1, 60)) {
         _slomo = !_slomo
      }

      if (!_slomo || Tic.btnp(6, 1, 30)) {
         Scene.update(1)
         Scene.draw()
         Debug.draw()
      }
   }
}