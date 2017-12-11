// title:  game title
// author: game developer
// desc:   short description
// script: wren

// FIXME: platforms still all messed up. perhaps i need to not count collisions in check if they started in a colliding state
// probably should make a proper pool of collisioninfo objects

var DIM_HORIZ = 1
var DIM_VERT = 2

var DIR_LEFT = 1
var DIR_RIGHT = 2
var DIR_TOP = 4
var DIR_BOTTOM = 8

class Math {
   static sign(a) { a < 0 ? -1 : 1 }
   static max(a, b) { a > b ? a : b }
   static min(a, b) { a < b ? a : b }
   static clamp(min, val, max) { val > max ? max : val < min ? min : val }
   static rectIntersect(x1, y1, w1, h1, x2, y2, w2, h2) { x1 < x2 + w2 && x1 + w1 > x2 && y1 < y2 + h2 && y1 + h1 > y2 }
}

class Timer {
   static init() {
      __fibers = []
   }

   static clear() {
      __fibers.clear()
   }

   static runLater(time, func) {
      var f = Fiber.new {
         while (time > 0) {
            var t = Fiber.yield()
            time = time - t
         }

         func.call()
      }

      __fibers.add(f)
   }

   static tick(t) {
      for (f in __fibers) {
         f.call(t)
      }

      if (__fibers.count == 0) {
         return
      }
      
      for (i in __fibers.count-1..0) {
         if (__fibers[i].isDone) {
            __fibers.removeAt(i)
         }
      }
   }
}

class Debug {
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

   static text(val) {
      text(val, "")
   }

   static text(key, val) {
      if (!__init) {
         __lines = []
         __init = true
      }
      __lines.add([key, val])
   }

   static draw() {
      var y = 130

      for (line in __lines) {
         Tic.print(line[0], 0, y)
         Tic.print(line[1], 32, y)
         y = y - 8
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

   query(x, y, w, h, dim, d, resolveFn) {
      if (dim == DIM_HORIZ) {
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
      } else {
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
   cx { _cx }
   cx=(cx) { _cx = cx }
   cy { _cy }
   cy=(cy) { _cy = cy }
   dx { _dx }
   dx=(dx) { _dx = dx }
   dy { _dy }
   dy=(dy) { _dy = dy }
   active { _active }
   active=(a) { _active = a }

   world { _world }

   xCollide { _xCollide }
   yCollide { _yCollide }
   
   construct new(world, ti, x, y, w, h) {
      _world = world
      _active = true
      _x = x
      _y = y
      _w = w
      _h = h
      _dx = 0
      _dy = 0
      _cx = 0
      _cy = 0

      _xCollide = Collision.new(0, null, 0)
      _yCollide = Collision.new(0, null, 0)
   }
   
   intersects(other) {
      return Math.rectIntersect(x, y, w, h, other.x, other.y, other.w, other.h)
   }

   // modified SAT, always resolves based on the axis passed in, not the nearest
   // always checks one dimension per call
   collide(other, dim, d) {
      var ldx = dim == DIM_HORIZ ? d : 0
      var ldy = dim == DIM_VERT ? d : 0

      var ox = this.x + (this.w / 2) + ldx - other.x - (other.w / 2)
      var px = (this.w / 2) + (other.w / 2) - ox.abs

      if (px <= 0) {
         return d
      }
      
      var oy = this.y + (this.h / 2) + ldy - other.y - (other.h / 2)
      var py = (this.h / 2) + (other.h / 2) - oy.abs

      if (py <= 0) {
         return d
      }

      if (dim == DIM_HORIZ) {
         var rx = ldx + px * Math.sign(ox)
         return rx 
      } else {
         var ry = ldy + py * Math.sign(oy)
         return ry
      }
   }

   check(dim, d) {
      var member = dim == DIM_HORIZ ? _xCollide : _yCollide
      var dir = dim == DIM_HORIZ ? (d > 0 ? DIR_RIGHT : DIR_LEFT) : (d > 0 ? DIR_TOP : DIR_BOTTOM)
      d = _world.tileCollider.query(_x, _y, _w, _h, dim, d, resolve)

      if (d == 0) {
         return member.update(d, null, dir)
      }

      var collideEnt = null

      for (ent in _world.entities) {
         if (ent != this && (ent.w > 0 || ent.h > 0)) {
            var tmp = this.collide(ent, dim, d)
            if (tmp != d) {
               collideEnt = ent

               if (ent.canCollide(this, dir, d)) {
                  d = d > 0 ? Math.min(d, tmp) : Math.max(d, tmp)
               }
            }
         }
      }

      return member.update(d, collideEnt, dir)
   }

   triggerTouch() {
      if (_xCollide.entity != null) {
         _xCollide.entity.touch(this, _xCollide.side == DIR_LEFT ? DIR_RIGHT : DIR_LEFT)
      }

      if (_yCollide.entity != null) {
         _yCollide.entity.touch(this, _yCollide.side == DIR_TOP ? DIR_BOTTOM : DIR_TOP)
      }
   }

   canCollide(other, side, d){ true }
   touch(other, side){}
   think(dt){}
   draw(t){}
}

class MovingPlatform is Entity {
   resolve { _resolve }
    
   construct new(world, ti, ox, oy) {
      super(world, ti, ox, oy, 24, 0)
      _dist = 0
      _d = 0

      _targetResolve = Fn.new { |side, tile, tx, ty, ldx, ldy|
         if (tx == _ignoreX && ty == _ignoreY) {
            return false
         }

         if (tile >= 245 && tile <= 252) {
            return true
         }

         return false
      }

      _resolve = Fn.new { |side, tile, tx, ty, ldx, ldy| false }

      setDirection(ti)
      setNextPoint()
   }

   canCollide(other, side, d) {
      //Debug.text("ret", "%(side) == %(DIR_TOP) && %(other.y)+%(other.h) <= %(y) && %(other.y)+%(other.h)+%(other.dy) > %(y)")
      return side == DIR_TOP && other.y+other.h <= y && other.y+other.h+d > y
   }

   setDirection(ti) {
      ti = ti - 245
      if (ti > 3) {
         ti = ti - 4
      }

      _dim = ti % 2 == 0 ? DIM_VERT : DIM_HORIZ
      _d = ti == 0 || ti == 3 ? -0.5 : 0.5
   }

   setNextPoint() {
      if (_d == 0 || _dim == 0 || _dist > 0) {
         return
      }

      _ignoreX = x / 8
      _ignoreY = y / 8

      var t = Tic.mget(_ignoreX, _ignoreY)
      setDirection(t)

      _dist = world.tileCollider.query(x, y, 1, 1, _dim, _d*2048, _targetResolve)

      if (_dist.abs == 2048) {
         _d = 0
         return
      }

      _dist = _dist.abs + (_d > 0 ? 1 : 8)
   }

   think(dt) {
      if (_movedTime == world.time) {
         return
      }
      _movedTime = world.time

      setNextPoint()

      dx = (_dim == DIM_HORIZ ? _d : 0)
      dy = (_dim == DIM_VERT ? _d : 0)
      _dist = _dist - _d.abs

      var chkx = check(DIM_HORIZ, dx)
      var chky = check(DIM_VERT, dy)

      // if the platform is going to lift the player up, attach them to this and lift them
      if (chky.entity is Player && chky.entity.groundEnt != this && intersects(chky.entity) == false) {
         chky.entity.groundEnt = this
         chky.entity.y = chky.entity.y + chky.entity.check(DIM_VERT, dy).delta
         // Debug.text("attach")
      }

      x = x + dx
      y = y + dy

      // Debug.text("p", "%(x),%(y) %(_dist)s")
   }

   draw(t) {
      Tic.rect(cx, cy, w, 4, 4)
   }
}

class Coin is Entity {
   construct new(world, ti, ox, oy) {
      super(world, ti, ox, oy, 8, 8)
      world.totalCoins = world.totalCoins + 1
   }

   canCollide(other, side, d) { false }

   touch(other, side) {
      if (other is Player == false) {
         return
      }

      active = false
      world.coins = world.coins + 1
   }

   draw(t) {
      Tic.spr(256 + (t / 8 % 4).floor, cx, cy, 0)      
   }
}

class LevelExit is Entity {
   construct new(world, ti, ox, oy) {
      super(world, ti, ox, oy, 8, 8)
   }

   canCollide(other, side, d){ false }

   draw(t) {
      Tic.spr(254, cx, cy)
   }

   touch(other, side) {
      if (other is Player == false) {
         return
      }

      active = false
      other.disableControls = true
      world.entities.add(ExitBanner.new(world))
      world.drawHud = false
      Timer.runLater(360, Fn.new {
         Scene.intro(world.levelNum + 1)
      })
   }
}

class ExitBanner is Entity {
   construct new(world) {
      super(world, 0, 0, 0, 0, 0)
   }

   draw(t) {
      Tic.rect(0, 40, 240, 56, 5)
      Tic.print("Level Cleared", 45, 45, 15, false, 2)
      Tic.print("Now, lets move on to the next one!", 27, 60)
      if (world.totalCoins > 0) {
         var pct = (world.coins / world.totalCoins *100).floor
         Tic.print("Coins ........ %(pct)\%", 60, 75, 15, true)
      }
   }
}

class Player is Entity {
   resolve { _resolve }
   disableControls=(b) { _disableControls = b }
   pMeter { _pMeter }
   pMeterCapacity { _pMeterCapacity }
   groundEnt { _groundEnt }
   groundEnt=(ent) { _groundEnt = ent }
   
   construct new(world, ti, ox, oy) {
      super(world, ti, ox, oy - 4, 7, 12)

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
      _disableControls = false

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

   think(dt) {
      var dir = _disableControls ? 0 : Tic.btn(2) ? -1 : Tic.btn(3) ? 1 : 0
      var jumpPress = _disableControls ? false : Tic.btn(4)
      var speed = 0

      // track if on the ground this frame
      var grav = check(DIM_VERT, 1)

      if (dy >= 0 && grav.delta < 1) {
         // if (grav.delta > 0) { Debug.text("snap") }
         y = y + grav.delta
         _grounded = true
         _groundEnt = grav.entity
      } else {
         _grounded = false
         _groundEnt = null
      }

      // some rotten code here. if we're close to a platform, snap onto it
      // also something similar in MovingPlatform.think so the moving plat will catch us
      if (_groundEnt is MovingPlatform) {
         var plat = grav.entity
         plat.think(dt)
         // Debug.text("y+h", y+h)
         // Debug.text("platy", plat.y)
         y = y + check(DIM_VERT, plat.dy).delta
         x = x + check(DIM_HORIZ, plat.dx).delta
         // Debug.text("y+h", y+h)
      }

      // track frames since leaving platform for late jump presses
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
      var chkx = check(DIM_HORIZ, dx)
      x = x + chkx.delta
      var chky = check(DIM_VERT, dy)
      y = y + chky.delta

      // don't trigger the same entity twice
      if (chkx.entity == chky.entity) {
         chky.entity = null
      }

      triggerTouch()

      // if we hit either direction in x, stop momentum
      if (chkx.delta != dx) {
         dx = 0
      }

      if (chky.delta != dy) {
         // either dir, nullify y movement
         dy = 0
      }

      // update camera
      world.cam.window(x, y, 20)

      // Debug.text("y+h", y+h)

      // Debug.text("grnd", _groundEnt)
      // Debug.text("entx", chkx.entity)
      // Debug.text("enty", chky.entity)
      // Debug.text("x", x)
      // Debug.text("y", y)
      // Debug.text("dx", dx)
      // Debug.text("dy", dy)
      // Debug.text("spd", speed)
      // Debug.text("jmp", _jumpHeldFrames)
      // Debug.text("gnd", _grounded)

   }

   draw(t) {
      Tic.rect(cx, cy, w, h, 14)
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

   entToCamera(ent) {
      ent.cx = ent.x - x
      ent.cy = ent.y - y
   }

   toCamera(px,py) {
      return [px - x, py - y] 
   }

   toWorld(cx, cy) {
      return [cx + x, cy + y]
   }
}

class Level {
   x { _x }
   y { _y }
   w { _w }
   h { _h }

   construct new(x, y, w, h) {
      _x = x
      _y = y
      _w = w
      _h = h
   }
}

class World {
   time { _time }
   tileCollider { _tileCollider }
   cam { _cam }
   entities { _entities }
   levelNum { _levelNum }
   coins { _coins }
   coins=(c) { _coins = c }
   totalCoins { _totalCoins }
   totalCoins=(c) { _totalCoins = c }
   drawHud { _drawHud }
   drawHud=(b) { _drawHud = b }
   player { _player }

   construct new(i) {
      _getTile = Fn.new { |x, y|
         if (x < _level.x || x >= _level.x + _level.w) {
            return 1
         }

         return Tic.mget(x,y)
      }
      _tileCollider = TileCollider.new(_getTile, 8, 8)

      _entities = []
      _coins = 0
      _totalCoins = 0
      _time = 0
      _drawHud = true
      _levels = [
         Level.new(0, 0, 43, 17),
         Level.new(45, 0, 30, 17)
      ]

      _level = _levels[i]
      _levelNum = i
      _cam = Camera.new(8, 8, 240, 136)
      _cam.constrain(_level.x*8, _level.y*8, _level.w*8, _level.h*8)
      

      var entmappings = {
         255: Player,
         254: LevelExit,
         253: Coin,
         248: MovingPlatform,
         247: MovingPlatform,
         246: MovingPlatform,
         245: MovingPlatform,
      }

      for (y in _level.y.._level.y+_level.h) {
         for (x in _level.x.._level.x+_level.w) {
            var i = Tic.mget(x, y)
            var e = entmappings[i]
            if (e != null) {
               var ent = e.new(this, i, x*8, y*8)
               if (ent is Player) {
                  _entities.insert(0, ent)
                   _player = ent
               } else {
                  _entities.add(ent)
               }
            }

         }
      }

      _remap = Fn.new { |i, x, y|
         if (i >= 240) {
            return 0
         }
         return i
      }
   }

   update(dt) {
      _time = _time + dt
      Debug.text("time", time)

      for (ent in _entities) {
         ent.think(_time)
      }

      for (i in _entities.count-1..0) {
         if (_entities[i].active == false) {
            _entities.removeAt(i)
         }
      }
   }

   draw(t) {
      Tic.map(_cam.tx, _cam.ty, _cam.tw, _cam.th, 0 - _cam.x % 8, 0 - _cam.y % 8, -1, 1, _remap)

      for (ent in _entities) {
         cam.entToCamera(ent)
         ent.draw(t)
      }

      if (_drawHud && _player != null) {
         var pct = (_player.pMeter / _player.pMeterCapacity * 100).floor
         Tic.rect(0, 0, 240, 12, 1)
         Tic.spr(256, 110, 1, 0)  
         Tic.print("%(_coins)/%(_totalCoins)", 120, 3, 15, true)
         Tic.print("P>>> %(pct)\%", 4, 3, 15, true)
      }
   }
}

class Intro {
   construct new(num) {
      _num = num

      Timer.runLater(120, Fn.new {
         Scene.level(_num)
      })
   }

   update(t) {

   }

   draw(t) {
      Tic.cls(2)
      Tic.print("ENTERING LEVEL %(_num+1)", 70, 60)
   }
}

class Scene {
   static intro(num) {
      Timer.clear()
      __world = Intro.new(num)
   }

   static level(num) {
      Timer.clear()
      num = num % 2
      __world = World.new(num)
   }

   static update(i) {
      __world.update(i)
   }

   static draw(t) {
      __world.draw(t)
   }
}

class Game is Engine { 
   construct new(){
      Debug.init()
      Timer.init()
      _slomo = false
      _time = 0
      Scene.level(0)
   }
   
   update(){
      _time = _time + 1
      if (Tic.btnp(7, 1, 60)) {
         _slomo = !_slomo
      }

      if (!_slomo || Tic.btnp(6, 1, 30)) {
         Scene.update(1)
         Scene.draw(_time)
         Timer.tick(1)
         Debug.draw()
      }
   }
}