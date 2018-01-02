// title:  game title
// author: game developer
// desc:   short description
// script: wren

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

// don't bother releasing since nothing ever needs for more than a single frame.
// just cycle through the 16
class CollisionPool {
   static init() {
      __pool = []
      __curr = 0
      __max = 16

      for (i in 1..__max) {
         __pool.add(Collision.new(0, null, 0))
      }
   }
   
   static get() {
      var res = __pool[__curr]
      res.clear()
      __curr = (__curr + 1) % __max
      return res
   }
}

// storage class since we need to know distance to trigger to filter
// them out during movement
class TriggerInfo {
   delta { _delta }
   entity { _entity }
   construct new(delta, entity) {
      _delta = delta
      _entity = entity
   }
}

// storage class for collision. don't alloc these directly, use CollisionPool
class Collision {
   delta { _delta }
   entity { _entity }
   entity=(e) { _entity = e }
   side { _side }
   triggers { _triggers }

   construct new(delta, entity, side) {
      set(delta, entity, side)
   }

   clear() {
      _delta = 0
      _entity = null
      _side = 0
      _triggers = []
   }

   // since we can trigger multiple entities per frame, we need to store
   // all that we can possibly collide with, and then filter out ones that
   // are too far away at the end.
   addTrigger(delta, entity) {
      _triggers.add(TriggerInfo.new(delta, entity))
   }

   filterTriggers(delta) {
      if (_triggers.count == 0) {
         return
      }

      for (i in _triggers.count-1..0) {
         if (delta.abs < _triggers[i].delta.abs) {
            _triggers.removeAt(i)
         }
      }
   }

   // returns true if the specified ent class is one that the collision ran into
   // should probably use properties or some sort of ECS-esque system but this
   // works good enough
   triggerHas(classname) {
      for (t in _triggers) {
         if (t.entity is classname) {
            return true
         }
      }

      return false
   }

   set(delta, entity, side) {
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
   baseResolve { _baseResolve }
   
   construct new(world, ti, x, y, w, h) {
      _world = world
      _trigger = false
      _active = true
      _x = x
      _y = y
      _w = w
      _h = h
      _dx = 0
      _dy = 0
      _cx = 0
      _cy = 0

      // allow multiple entities to use this so they all react to the world similarly
      _baseResolve = Fn.new { |side, tile, tx, ty, ldx, ldy|
         if (tile == 0) {
            return false
         }

         if (tile >= 224) {
            // editor only item
            return false
         }

         if (tile >= 4 && tile <= 6) {
            //Debug.text("plat", "%(ty), %(side == DIR_BOTTOM) && %(y+h) <= %(ty*8) && %(y+h+ldy) > %(ty*8)")
            return side == DIR_BOTTOM && _y+_h <= ty*8 && _y+_h+ldy > ty*8
         }

         return true
      }
   }
   
   // returns true if this rect intersects with the other ent's rect
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

   // one place to try moving through the world. checks tiles in the way, and all entities
   // probably want some sort of spatial partitioning eventually, but rect intersects are cheap
   check(dim, d) {
      var dir = dim == DIM_HORIZ ? (d > 0 ? DIR_RIGHT : DIR_LEFT) : (d > 0 ? DIR_TOP : DIR_BOTTOM)
      d = _world.tileCollider.query(_x, _y, _w, _h, dim, d, resolve)

      var colInfo = CollisionPool.get()

      if (d == 0) {
         return colInfo.set(d, null, dir)
      }

      var collideEnt = null

      for (ent in _world.entities) {
         if (ent != this && ent.active && (ent.w > 0 || ent.h > 0)) {
            var tmp = this.collide(ent, dim, d)
            if (tmp != d) {
               if (ent.canCollide(this, dir, d)) {
                  if (ent.trigger) {
                     colInfo.addTrigger(d, ent)
                  } else {
                     collideEnt = ent
                     d = tmp.abs < d.abs ? tmp : d
                  }

               }
            }
         }
      }

      colInfo.filterTriggers(d)

      return colInfo.set(d, collideEnt, dir)
   }

   // called from subclassed entities when you want to activate all entities
   // the collision is moving into
   triggerTouch(collision) {
      if (collision.entity != null) {
         collision.entity.touch(this, collision.side)
      }

      for (trigger in collision.triggers) {
         trigger.entity.touch(this, collision.side)
      }
   }

   // return true or false based on if the receiving entity wants to collide this frame
   canCollide(other, side, d){ true } 
   // if true, it will not impede movement
   trigger { false }
   // if true, player will track and move before player moves
   platform { false }
   // called when another entity collides with you
   touch(other, side){}
   // called every frame
   think(dt){}
   draw(t){}
}

// flames actually spawn out of a tile in the tilemap range. the flamethrower is solid
// but we spawn the flame and toggle it on and off instead to cut back on entities used
class Flame is Entity {
   construct new(world, ti, ox, oy) {
      _dim = ti % 2 == 0 ? DIM_HORIZ : DIM_VERT
      var w = _dim == DIM_HORIZ ? 16 : 6
      var h = _dim == DIM_HORIZ ? 6 : 16
      
      ti = ti - 7
      _delay = 0
      if (ti > 3) {
         ti = ti - 4
         _delay = 240
      }
      _tile = ti

      if (ti == 0 || ti == 3) {
         ox = ox + (_dim == DIM_HORIZ ? -16 : 1)
         oy = oy + (_dim == DIM_HORIZ ? 1 : -16)
      } else {
         ox = ox + (_dim == DIM_HORIZ ? 8 : 1)
         oy = oy + (_dim == DIM_HORIZ ? 1 : 8)
      }

      super(world, ti, ox, oy, w, h)
   }  

   isHurting() {
      var cyc = (world.time + _delay) % 480
      return cyc > 300
   }

   isFiringUp() {
      var cyc = (world.time + _delay) % 480
      return cyc > 240 && cyc < 300
   }

   canCollide(other, side, d) { true }
   trigger { true }

   touch(other, side) {
      if (other is Player == false) {
         return
      }

      if (isHurting() == false) {
         return
      }

      other.hurt(this, 1)
   }

   draw(t) {
      var spr = 263
      if (isHurting() == false) {
         if (isFiringUp()) {
            spr = 264
         } else {
            return
         }     
      }

      var flicker = (t / 3 % 2).floor == 0

      if (_dim == DIM_VERT) {
         var f = flicker ? 1 : 0
         var flip = _tile == 2 ? 2 + f : f
         Tic.spr(spr, cx - 1, cy, 1, 1, flip, 0, 1, 2)
      } else {
         var f = flicker ? 2 : 0
         var flip = _tile == 3 ? 1 + f : f
         Tic.spr(spr, cx, cy - 1, 1, 1, flip, 1, 1, 2)         
      }
   }
}

// springs work like moving platforms, and will be called from the player's think early on
// this would probably be cleaner if i could query to see if any entities are standing on the spring
// and trigger the bounce on them instead of having the player check.
class Spring is Entity {
   platform { true }

   construct new(world, ti, ox, oy) {
      super(world, ti, ox, oy, 8, 8)
      _activateTime = -1
      _thinkTime = 0
      _baseY = oy
      _delay = 3
      _activated = false
   }

   // springs dont activate immediately, they activate a few frames later
   framesUntilTrigger { _activateTime == -1 ? _delay : _delay - ((world.time - _activateTime) / _delay).floor }

   // they work like platforms, only collide from the top going down
   canCollide(other, side, d) {
      return side == DIR_TOP && other.y+other.h <= y && other.y+other.h+d > y
   }

   // start the animation
   touch(other, side) {
      if (other is Player == false) {
         return
      }

      if (_activateTime == -1) {
         _activateTime = world.time
      }
   }

   trigger() {
      y = _baseY
      dy = 0
      _activateTime = -1
      _activated = true
   }

   // if we're activated this frame, return the bounce amount
   // otherwise return 0
   checkSpring() {
      return _activated ? -3.6 : 0
   }

   think(dt) {
      if (_thinkTime == world.time) {
         return
      }
      _thinkTime = world.time

      if (_activateTime == -1) {
         _activated = false
         return
      }

      // set us up if we're set to activate. if there's a player on us, this think
      // will be run before the player calls checkSpring
      if (framesUntilTrigger <= 0) {
         trigger()
      } else {
         // since we work like a moving platform, move down and shrink
         // the player will stick to us
         dy = 2
         y = _baseY + (_delay - framesUntilTrigger) * 2
      }
   }

   draw(t) {
      var frm = _activateTime == -1 ? _delay : framesUntilTrigger
      Tic.spr(263 - frm, cx, cy, 0)      
   }
}

class Cannonball is Entity {
   parent { _parent }
   parent=(ent) { _parent = ent }

   resolve { baseResolve }

   construct new(world, ti, ox, oy) {
      super(world, ti, ox, oy, 8, 8)
      dx = -0.5
      dy = 0
      _parent = null
   }

   canCollide(other, side, d) { true }
   trigger { true }

   touch(other, side) {
      active = false
      // don't hurt from the top
      if (other is Player && side != DIR_TOP) {
         other.hurt(this, 1)
      }
   }

   // move our speed every frame. if we hit something, activate touch on ourselves
   // and explode
   think(dt) {
      var chkx = check(DIM_HORIZ, dx)
      if (chkx.entity != null && chkx.entity != _parent) {
         touch(chkx.entity, chkx.side)
      }
      x = x + dx

      var chky = check(DIM_VERT, dy)
      if (chky.entity != null && chky.entity != _parent) {
         touch(chky.entity, chky.side)
      }
      y = y + dy

      // die if we go off the level
      if ( y > (world.level.y + world.level.h + 2) * 8 || y < world.level.y) {
         active = false
         return
      }

      if ( x > (world.level.x + world.level.w) * 8 || x < world.level.x) {
         active = false
         return
      }
   }

   draw(t) {
      Tic.spr(270, cx, cy, 13)      
   }
}

class Cannon is Entity {
   construct new(world, ti, ox, oy) {
      super(world, ti, ox, oy, 8, 8)
      _tile = ti

      ti = ti - 238
      _dim = ti % 2 == 0 ? DIM_VERT : DIM_HORIZ
      _d = ti == 0 || ti == 3 ? -0.5 : 0.5

      _fireTime = world.time + 60
   }

   canCollide(other, side, d) { true }

   think(dt) {
      if (world.time < _fireTime) {
         return
      }

      // don't fire if we're too close or too far away
      var dist = (world.player.x - x).abs
      if (dist <= 16 || dist > 200) {
         // don't wait a full cycle to retry
         _fireTime = world.time + 60
         return
      }

      // spawn a cannonball, set parent to this so it doesn't immediately explode
      var ball = Cannonball.new(world, 270, x, y)
      ball.parent = this
      ball.dx = _dim == DIM_HORIZ ? _d : 0
      ball.dy = _dim == DIM_VERT ? _d : 0
      world.entities.add(ball)

      // recharge
      _fireTime = world.time + 300
   }

   draw(t) {
      Tic.spr(_tile, cx, cy, 13)      
   }
}

// spikes just hurt players when touched
class Spike is Entity {
   construct new(world, ti, ox, oy) {
      super(world, ti, ox, oy, 8, 8)
   }

   canCollide(other, side, d) { true }

   touch(other, side) {
      if (other is Player == false) {
         return
      }

      other.hurt(this, 1)
   }

   draw(t) {
      Tic.spr(242, cx, cy, 0)      
   }
}

class FallingPlatform is Entity {
   platform { true }
   construct new(world, ti, ox, oy) {
      super(world, ti, ox, oy, 24, 4)

      _fallTime = 0
      _fallSpeed = 1
   }

   canCollide(other, side, d) {
      return side == DIR_TOP && other.y+other.h <= y && other.y+other.h+d > y
   }

   touch(other, side) {
      if (other is Player == false) {
         return
      }

      // if a player touches us, wait a bit and then start falling
      if (_fallTime == 0) {
         _fallTime = other.world.time + 10
         dy = _fallSpeed
      }
   }

   think(dt) {
      if (_movedTime == world.time) {
         return
      }
      _movedTime = world.time

      // die if we've fallen off the level
      if ( y > (world.level.y + world.level.h + 2) * 8) {
         active = false
         return
      }

      // keep moving down
      if (_fallTime > 0 && world.time > _fallTime) {
         y = y + dy
      }

   }

   draw(t) {
      Tic.spr(244, cx, cy, 0)
      Tic.spr(244, cx+8, cy, 0)
      Tic.spr(244, cx+16, cy, 0)
   }
}

class MovingPlatform is Entity {
   resolve { _resolve }
   platform { true }
    
   construct new(world, ti, ox, oy) {
      super(world, ti, ox, oy, 24, 0)
      _dist = 0 // how far before we reach our target
      _d = 0 // speed
      _dim = 0 // what axis we're moving on

      // passed into tilecollider to find the next turn 
      _targetResolve = Fn.new { |side, tile, tx, ty, ldx, ldy|
         // don't collide with our current turn tile
         if (tx == _ignoreX && ty == _ignoreY) {
            return false
         }

         if (tile >= 245 && tile <= 252) {
            return true
         }

         return false
      }

      // never collide with any tile during movement
      _resolve = Fn.new { |side, tile, tx, ty, ldx, ldy| false }

      // set initial direction based on spawn and then the first destination
      setDirection(ti)
      setNextPoint()
   }

   // moving platforms work like one way. only collide if you're falling through from the top
   canCollide(other, side, d) {
      //Debug.text("ret", "%(side) == %(DIR_TOP) && %(other.y)+%(other.h) <= %(y) && %(other.y)+%(other.h)+%(other.dy) > %(y)")
      return side == DIR_TOP && other.y+other.h <= y && other.y+other.h+d > y
   }

   setDirection(ti) {
      ti = ti - 245
      // spawns also act as turns.
      if (ti > 3) {
         ti = ti - 4
      }

      _dim = ti % 2 == 0 ? DIM_VERT : DIM_HORIZ
      _d = ti == 0 || ti == 3 ? -0.5 : 0.5
   }

   setNextPoint() {
      // if we've still got time to go, or we couldn't find a valid target
      if (_d == 0 || _dim == 0 || _dist > 0) {
         return
      }

      // we need a new destination. don't consider the one we're on top of now
      _ignoreX = x / 8
      _ignoreY = y / 8

      // but we do need to know which way we're about to go!
      var t = Tic.mget(_ignoreX, _ignoreY)
      setDirection(t)

      // go a long way out to find how far our next target is
      _dist = world.tileCollider.query(x, y, 1, 1, _dim, _d*2048, _targetResolve)

      // if we don't have a destination, just freeze it in place
      if (_dist.abs == _d*2048) {
         _dim = 0
         _d = 0
         return
      }

      // offset for size of platform
      _dist = _dist.abs + (_d > 0 ? 1 : 8)
   }

   think(dt) {
      // don't move twice in a frame in case a player called us
      if (_movedTime == world.time) {
         return
      }
      _movedTime = world.time

      // figure out if we need a new destination
      setNextPoint()

      // calculate our movement vector
      dx = (_dim == DIM_HORIZ ? _d : 0)
      dy = (_dim == DIM_VERT ? _d : 0)

      // this is only used to detect if we run into a player. we always move our speed every frame
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

      // subtract our distance remaining
      _dist = _dist - _d.abs

      // Debug.text("p", "%(x),%(y) %(_dist)s")
   }

   draw(t) {
      Tic.spr(272, cx, cy, 0, 1, 0, 0, 3, 1)
   }
}

class Coin is Entity {
   construct new(world, ti, ox, oy) {
      super(world, ti, ox, oy, 8, 8)
      world.totalCoins = world.totalCoins + 1
   }

   canCollide(other, side, d) { other is Player == true }
   trigger { true }

   touch(other, side) {
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

   canCollide(other, side, d) { other is Player == true }
   trigger { true }

   draw(t) {
      Tic.spr(268 + (t / 7 % 2).floor, cx, cy, 0)
   }

   touch(other, side) {
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
   resolve { baseResolve }
   disableControls=(b) { _disableControls = b }
   pMeter { _pMeter }
   pMeterCapacity { _pMeterCapacity }
   groundEnt { _groundEnt }
   groundEnt=(ent) { _groundEnt = ent }
   health { _health }
   
   construct new(world, ti, ox, oy) {
      super(world, ti, ox, oy - 4, 7, 12)

      _grounded = true
      _fallingFrames = 0
      _pMeter = 0
      _jumpHeld = false
      _jumpHeldFrames = 0
      _groundEnt = null
      _disableControls = false
      _health = 3
      _invulnTime = 0

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
      _enemyJumpHeld = 2.75
      _enemyJump = 1.9
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

   die() {
      active = false
      Timer.runLater(60, Fn.new {
         Scene.intro(world.levelNum)
      })
   }

   hurt(other, amount) {
      if (world.time < _invulnTime) {
         return
      }

      _health = _health - amount
      _invulnTime = world.time + 120

      if (_health <= 0) {
         die()
      }   
   }

   think(dt) {
      var dir = _disableControls ? 0 : Tic.btn(2) ? -1 : Tic.btn(3) ? 1 : 0
      var jumpPress = _disableControls ? false : Tic.btn(4)
      var speed = 0

      // track if on the ground this frame
      var grav = check(DIM_VERT, 1)

      // snap to the ground if we're near it (needed for sticking to falling platforms)
      if (dy >= 0 && grav.delta < 1) {
         // if (grav.delta > 0) { Debug.text("snap") }
         y = y + grav.delta
         _grounded = true
         _groundEnt = grav.entity
         // trigger touch on things you're standing on, since gravity won't trigger it
         triggerTouch(grav)
      } else {
         _grounded = false
         _groundEnt = null
      }

      // if we're on a platform, move the platform first
      if (_groundEnt && _groundEnt.platform) {
         _groundEnt.think(dt)
         // Debug.text("y+h", y+h)
         // Debug.text("platy", _groundEnt.y)
         if (_groundEnt is Spring) {
            // this will kill the ability to jump too, even if the spring isn't ready to activate yet
            dy = _groundEnt.checkSpring()
            _grounded = false
            _jumpHeld = jumpPress && _jumpHeldFrames < _earlyJumpFrames * 2
         }

         y = y + check(DIM_VERT, _groundEnt.dy).delta
         x = x + check(DIM_HORIZ, _groundEnt.dx).delta
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
      if (_groundEnt is Spring == false) {
         var chkx = check(DIM_HORIZ, dx)
         x = x + chkx.delta
         triggerTouch(chkx)

         // if we hit either direction in x, stop momentum
         if (chkx.delta != dx) {
            dx = 0
         }
      }

      var chky = check(DIM_VERT, dy)
      y = y + chky.delta
      triggerTouch(chky)



      if (chky.side == DIR_TOP && chky.triggerHas(Cannonball)) {
         dy = jumpPress ? -_enemyJumpHeld : -_enemyJump
         _jumpHeld = jumpPress
      } else if (chky.delta != dy) {
         // either dir, nullify y movement
         dy = 0
      }

      // update camera
      world.cam.window(x, y, 20)

      if ( y > (world.level.y + world.level.h) * 8) {
         _health = 0
         die()
      }

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
      var color = world.time < _invulnTime ? 15 : 14
      Tic.rect(cx, cy, w, h, color)
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
   level { _level }
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
         244: FallingPlatform,
         243: Spring,
         242: Spike,
         241: Cannon,
         240: Cannon,
         239: Cannon,
         238: Cannon,
         14: Flame,
         13: Flame,
         12: Flame,
         11: Flame,
         10: Flame,
         9: Flame,
         8: Flame,
         7: Flame,
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
         if (i >= 224) {
            return 0
         }
         return i
      }
   }

   update(dt) {
      _time = _time + dt
      //Debug.text("time", time)
      //Debug.text("ents", _entities.count)

      for (ent in _entities) {
         if (ent.active) {
            ent.think(dt)
         }
      }

      for (i in _entities.count-1..0) {
         if (_entities[i].active == false) {
            _entities.removeAt(i)
         }
      }
   }

   draw(t) {
      Tic.cls(2)
      Tic.map(_cam.tx, _cam.ty, _cam.tw, _cam.th, 0 - _cam.x % 8, 0 - _cam.y % 8, 2, 1, _remap)

      for (ent in _entities) {
         if (ent.active) {
            cam.entToCamera(ent)
            ent.draw(t)
         }
      }

      if (_drawHud && _player != null) {
         Tic.rect(0, 0, 240, 12, 1)
         if (_totalCoins > 0) {
            Tic.spr(256, 100, 1, 0)
            Tic.print("%(_coins)/%(_totalCoins)", 110, 3, _coins == _totalCoins ? 14 : 15, true)
         }
         Tic.print("S", 4, 3, 15, true)

         for (i in 0..2) {
            Tic.spr(i < _player.health ? 265 : 281, 198+(i*14), 2, 0, 1, 0, 0, 2, 1)
         }

         var pct = (_player.pMeter / _player.pMeterCapacity * 40 / 8).floor
         for (i in 0..4) {
            Tic.spr(i < pct ? 283 : 267, 11 + i * 6, 2, 0)
         }
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
      System.gc()
   }

   static level(num) {
      Timer.clear()
      num = num % 2
      __world = World.new(num)
      System.gc()
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
      CollisionPool.init()
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