pico-8 cartridge // http://www.pico-8.com
version 36
__lua__
--pinballvania
--by cveinnt
--originally by guerragames
poke(0x5f2d,1)

one_frame=1/60
cpu=stat(1)

game_time=0

--
cartdata("pinballvania")

game_saved=0
show_gameover=false

--
function game_load()
 game_time,current_level,new_game_plus=dget(0),dget(1),dget(2)
 current_level=max(1,current_level)
end

--
function game_save()
 dset(0,game_time)
 dset(1,current_level)
 dset(2,new_game_plus)
 
 game_saved=2
end

--
function game_reset()
 game_time,current_level,new_game_plus=0,1,0
 
 game_save()
 run()
end

--
align_l,align_r=1,2

function print_outline(t,x,y,c,bc,a)
 local ox=#t*2 
 if a==align_l then
  ox=0
 elseif a==align_r then
  ox=#t*4
 end
 local tx=x-ox
 color(bc)
 print(t,tx-1,y)print(t,tx-1,y-1)print(t,tx,y-1)print(t,tx+1,y-1)
 print(t,tx+1,y)print(t,tx+1,y+1)print(t,tx,y+1)print(t,tx-1,y+1)
 print(t,tx,y,c)
end

--
function time_to_text(time)
 local hours,mins,secs,fsecs=flr(time/3600),flr(time/60%60),flr(time%60),flr((time%60)*10)%10
 if(hours<0 or hours>9)return "8:59:59"
 local txt=hours>0 and hours..":" or ""
 txt=txt..((mins>=10 or hours==0) and mins or "0"..mins)
 txt=txt..(secs<10 and ":0"..secs or ":"..secs).."."..fsecs
 return txt
end

--
function dot(x1,y1,x2,y2)
 return x1*x2+y1*y2
end

--
function mag(x,y)
  local d=max(abs(x),abs(y))
  local n=min(abs(x),abs(y))/d
  return sqrt(n*n+1)*d
end

--
function normalize(x,y)
  local m=mag(x,y)
  return x/m,y/m,m
end

--
function next_i(l,i)
 i+=1
 if(i>#l)i=1
 return i
end

--
function find_next_i(l,i,active_count)
 if active_count>=#l then
  return nil,0
 end
 
 local o=l[i]
 while o.active do
  i=next_i(l,i)
  o=l[i]
 end
 
 return o,i
end

--
function reflect(x,y,nx,ny,restitution,friction)
 local d=dot(x,y,nx,ny)
 
 if d>0 then
  return x,y
 end

 local vnx,vny=-d*nx,-d*ny
 local tx,ty=x+vnx,y+vny
 
 local rx,ry=restitution*vnx+friction*tx,restitution*vny+friction*ty
 return rx,ry
end

-- matrix math

--
function matrix_rot(a)
 local sa=sin(a)
 local ca=cos(a)
 return {ca,-sa,0,
         sa,ca,0,
         0,0,1} 
end

--
function matrix_scale(s)
 return {s,0,0,
         0,s,0,
         0,0,1} 
end

--
function matrix_trans(tx,ty)
 return {1,0,tx,
         0,1,ty,
         0,0,1} 
end

--
function matrix_mul(a,b)
 return { a[1]*b[1]+a[2]*b[4]+a[3]*b[7],a[1]*b[2]+a[2]*b[5]+a[3]*b[8],a[1]*b[3]+a[2]*b[6]+a[3]*b[9],
          a[4]*b[1]+a[5]*b[4]+a[6]*b[7],a[4]*b[2]+a[5]*b[5]+a[6]*b[8],a[4]*b[3]+a[5]*b[6]+a[6]*b[9], 
          a[7]*b[1]+a[8]*b[4]+a[9]*b[7],a[7]*b[2]+a[8]*b[5]+a[9]*b[8],a[7]*b[3]+a[8]*b[6]+a[9]*b[9] }
end

--
function transform(v,m)
 return m[1]*v.x+m[2]*v.y+m[3],m[4]*v.x+m[5]*v.y+m[6]
end

--
function rotate_point( x, y, cosa, sina )
 return x*cosa - y*sina, x*sina + y*cosa
end

--
function scale_point( x, y, scalex, scaley )
 return scalex*x, scaley*y
end

------------------------
-- arrow
------------------------
arrow = {}
arrow.size = 5
arrow.scale = 1
arrow_disabled_t=5
--arrow.min_scale = 1
--arrow.max_scale = 2
--arrow.min_col_scale = 0.5
--arrow.max_col_scale = 1.8
arrow.x = 80
arrow.y = 80
arrow.tx,arrow.ty=80,80
--arrow.colors = {8,9,10,7,12}
arrow.nx = 1
arrow.ny = 0

arrow.points =
{
 { 0, 0},
 { 2, 2},
 { 1, 2},
 { 1, 4},
 {-1, 4},
 {-1, 2},
 {-2, 2},
 { 0, 0},
 { 0, 0},
}

--------------------------

arrow.draw = function(color)
 local st = 0.8*sin(t)
 local scale = arrow.scale
 local col_scale = arrow.scale
 
 arrow.x+=.1*(arrow.tx-arrow.x)
 arrow.y+=.1*(arrow.ty-arrow.y)
 
 --[[
 if scale < arrow.min_scale then
  scale = arrow.min_scale
 elseif scale > arrow.max_scale then
  scale = arrow.max_scale
 end
 if col_scale < arrow.min_col_scale then
  col_scale = arrow.min_col_scale
 elseif col_scale > arrow.max_col_scale then
  col_scale = arrow.max_col_scale
 end
 --]]
 --local color_index = 1 + flr( ((col_scale - arrow.min_col_scale)/(arrow.max_col_scale - arrow.min_col_scale) ) * (#arrow.colors-1))
 --local color = arrow.colors[color_index]
 
 local x,y = scale_point(arrow.points[1][1], arrow.points[1][2], scale*(arrow.size+st), scale*(arrow.size-st))
 local cosa = arrow.ny
 local sina = arrow.nx
 x,y = rotate_point(x,y,cosa,sina)
 
 for i=2,#arrow.points do
  local px,py = x,y
  x,y = scale_point(arrow.points[i][1], arrow.points[i][2],scale*(arrow.size+st), scale*(arrow.size-st))
  x,y = rotate_point(x,y,cosa,sina)
  
  local ax = arrow.x+x
  local ay = arrow.y+y
  local pax = arrow.x+px
  local pay = arrow.y+py
  line(ax+1,ay,pax+1,pay, 0)
  line(ax-1,ay,pax-1,pay, 0)
  line(ax,ay+1,pax,pay+1, 0)
  line(ax,ay-1,pax,pay-1, 0)

  line(ax+1,ay+1,pax+1,pay+1, 0)
  line(ax-1,ay-1,pax-1,pay-1, 0)
  line(ax-1,ay+1,pax-1,pay+1, 0)
  line(ax+1,ay-1,pax+1,pay-1, 0)
 end 

 for i=2,#arrow.points do
  local px,py = x,y
  x,y = scale_point(arrow.points[i][1], arrow.points[i][2],scale*(arrow.size+st), scale*(arrow.size-st))
  x,y = rotate_point(x,y,cosa,sina)
  line(arrow.x+x,arrow.y+y,arrow.x+px,arrow.y+py, color)
 end 
 
end

--
parts={}
parts_next,parts_blink=1,0

for i=0,400 do
 add(parts,{t=0})
end

parts_flags_floor_bounce,parts_flags_blink,parts_flags_no_outline=0x01,0x02,0x04

-- 
function parts_reset()
 for k,p in pairs(parts) do
  p.t=0
 end
end

--
function parts_spawn(t,x,y,vx,vy,g,d,s,ds,c,bc,f)
 parts_next=next_i(parts,parts_next)
 
 local p=parts[parts_next]
 
 p.t,p.x,p.y,p.vx,p.vy,p.g,p.d,p.s,p.ds,p.c,p.bc,p.f=t,x,y,vx,vy,g,d,s,ds,c,bc,f
end

--
function parts_update()
 parts_blink+=one_frame
 
 for k,p in pairs(parts) do
  if p.t>0 then
   p.t-=one_frame
   
   p.vx*=p.d
   p.vy*=p.d
   
   p.x+=p.vx
   p.y+=p.vy
   
   p.s=max(0,p.s+p.ds)
   
   if p.s<=0 then
    p.t=0
   end
   
   --[[]]
   if band(p.f,parts_flags_blink)==parts_flags_blink then
    if parts_blink%.2>.1 then 
     p.c,p.bc=p.bc,p.c
    end
   end
   --]]
   
   --if band(p.f,parts_flags_floor_bounce)==parts_flags_floor_bounce and s_floor(p.x,p.y+p.s) then
   -- if abs(p.vy)>.2 then
   --  p.vy=-.8*p.vy
   -- end
   --else
    p.vy+=p.g
   --end
  end
 end
end

--
function part_draw(p,o,c)
 local s=p.s+o
 
 if s<=1 then
  pset(p.x,p.y,c)
 else
  circfill(p.x,p.y,s-1,c)
 end
end

--
function parts_draw()
 for k,p in pairs(parts) do
  if p.t>0 then
   if band(p.f,parts_flags_no_outline)!=parts_flags_no_outline then
    part_draw(p,1,p.bc)
   end
  end
 end

 for k,p in pairs(parts) do
  if p.t>0 then
   part_draw(p,0,p.c)
  end
 end
end

--
function explosions_spawn(px,py,t,intensity,s,ds,count,c,bc)
 for i=1,count do
  local an,ra=rnd(),intensity+rnd(intensity)
  local vx,vy=ra*cos(an),ra*sin(an)

--parts_spawn(t, x, y,vx,vy,g, d, s, ds,c,bc,f)
  parts_spawn(t,px,py,vx,vy,0,.9,s,ds,c,bc,parts_flags_no_outline)
 end
end

--
function explosions_spawn_uniform(px,py,t,intensity,s,ds,count,c,bc)
 local an=0
 for i=1,count do
  local ra=intensity
  local vx,vy=ra*cos(an),ra*sin(an)

--parts_spawn(t, x, y,vx,vy,g, d, s, ds,c,bc,f)
  parts_spawn(t,px,py,vx,vy,0,.8,s,ds,c,bc,parts_flags_blink)
 
  an+=1/count
 end
end

--
cam_shake_x,cam_shake_y,cam_shake_damp=0,0,0
cam_shake_time=0
cam_shake_max_radius=0

--
function screenshake(max_radius,time)
 cam_shake_max_radius=max_radius
 cam_shake_time=time
end

--
function update_screeneffects()
 cam_shake_time=max(0,cam_shake_time-one_frame)
 
 if cam_shake_time>0 then
  local a=rnd()
  cam_shake_x,cam_shake_y=cam_shake_max_radius*cos(a),cam_shake_max_radius*sin(a)
 else
  cam_shake_x,cam_shake_y=0,0
 end
end

----------------------
-- camera
----------------------
cam_a=0
cam_aa=.0005
cam_va=0
cam_s=0
cam_trans_s=1
cam_x=0
cam_y=0
cam_matrix=matrix_scale(cam_s)

mouse_on=false
mouse_x,mouse_y=0,0
mouse_up,mouse_down,mouse_left,mouse_right=false,false,false,false

----------------------

function cam_update()
 cam_va*=.9
 if(abs(cam_va)<=.0002)cam_va=0
 
 mouse_on=stat(34)
 
 mouse_x,mouse_y=stat(32),stat(33)
 
 if mouse_on==1 then
  mouse_right=mouse_x>64
  mouse_up=mouse_y<48
  mouse_left=mouse_x<64
  mouse_down=mouse_y>80
 else
  mouse_up,mouse_down,mouse_left,mouse_right=false,false,false,false
 end
 
 if btn(0) or mouse_left then
  -- left
  cam_va+=cam_aa
 end
 
 if btn(1) or mouse_right then
  -- right
  cam_va-=cam_aa
 end
 
 if(cam_va>.005)cam_va=.005
 if(cam_va<-.005)cam_va=-.005
 
 cam_a+=cam_va
 
 if level_t<1 then
  if abs(player.x-cam_x)>2 or abs(player.y-cam_y)>2 then
   cam_x+=.1*(-player.x-cam_x)
   cam_y+=.1*(-player.y-cam_y)
  end
 else
  if abs(current_circle.x-cam_x)>2 or abs(current_circle.y-cam_y)>2 then
   cam_x+=.1*(-current_circle.x-cam_x)
   cam_y+=.1*(-current_circle.y-cam_y)
  end
 end
 
 local cc_scale=(3.5-current_circle.r/16)/cam_trans_s
 
 if abs(cc_scale-cam_s)>.1 then
  cam_s+=.1*(cc_scale-cam_s)
 end
 
 cam_matrix=matrix_mul( matrix_scale(cam_s), matrix_mul(matrix_rot(cam_a),matrix_trans(cam_x,cam_y)) )
end

-- player
player={}

--
function player_reset()
 player.radius=3
 player.lx,player.ly=0,0
 player.x,player.y=0,0
 player.vx,player.vy=0,0
 player_t=0
 player_flash=0
end

--
function player_bounce_ball(nx,ny)
 local pvx,pvy=player.vx,player.vy
 player.vx,player.vy=reflect(player.vx,player.vy,nx,ny,.8,1)

 local vnx,vny,m=normalize(player.vx,player.vy)

 if player.vx*pvx<-.25 or player.vy*pvy<-.25 then
  player_flash=.1
  local px,py=transform(player,cam_matrix)
  explosions_spawn(px,py,.4*m,min(3,2*m),min(3,2*m),-.1,12,10,9)
  screenshake(min(3,2*m),min(.15,.05*m))
 
  if m>2.5 then
   sfx(0,3)
  elseif m>2 then
   sfx(1,3)
  elseif m>1.5 then
   sfx(2,3)
  elseif m>1 then
   sfx(3,3)
  end
 end
end

--
function player_update()
 if(level_t<1)return
  
 player_t+=one_frame

 player_flash=max(0,player_flash-one_frame)

 local cam_ax,cam_ay=cos(-cam_a-.25),sin(-cam_a-.25)

 local drop_mag=.05
 
 if btn(3) or btn(4) or btn(5) or mouse_down then
  drop_mag=.2
 end

 local player_max_speed=3
 
 if level_finished and not is_title_level then
  local nx,ny,m=normalize(goal_circle.x-player.x,goal_circle.y-player.y)
  player.vx+=nx*.1
  player.vy+=ny*.1
  player_max_speed=1
 else
  player.vx+=drop_mag*cam_ax
  player.vy+=drop_mag*cam_ay
  player_max_speed=3
 end

 local pvnx,pvny,m=normalize(player.vx,player.vy)
 
 if m>player_max_speed then
  m=player_max_speed
  player.vx=m*pvnx
  player.vy=m*pvny
 end
 
 player.lx,player.ly=player.x,player.y
 player.x+=player.vx
 player.y+=player.vy
 
 local player_onground,nx,ny,m=circles_check_collision(player)
 
 if player_onground then
  player_bounce_ball(nx,ny)
  
  local vnx,vny,m=normalize(player.vx,player.vy)
  if m>.5 then
   sfx(5,2)
  else
   sfx(-2,2)
  end
 else
  sfx(-2,2)
 end
 
 local player_onobstacle,nx,ny=circles_check_obstacles(player)
 
 if player_onobstacle then
  if current_circle.is_bumper then
   current_circle.bumped_t=.2
   player_bounce_ball(-1.5*nx,-1.5*ny)
   
   if current_circle.boss_damaged_t>0 then
    sfx(9,1)
   else
    sfx(8,1)
   end
   
  else
   player_bounce_ball(-nx,-ny)
  end
 end
 
 -- check level win condition
 if current_circle==goal_circle then
  local exit_active=is_exit_active()
  
  if exit_active then
   local m=mag(player.x-current_circle.x,player.y-current_circle.y)
   
   if not level_finished and m>0 and m<current_circle.r/2 then
    level_finished=true
    level_finished_t=0
    if(not is_title_level)sfx(11,1)
   
    game_finished=not is_title_level and level_finished and current_level==20
   end
  end
 end
end

--
function player_draw()
 if(level_t<1)return
 
 local px,py=transform(player,cam_matrix)

 local psize=player.radius*cam_s

 circfill(px,py,psize,player_flash>0 and 10 or 5)
 circfill(px,py,psize-1,6)
 circfill(px+psize/4,py-psize/4,1,7)
end

-- level circles

next_level=1
current_level=1
max_level=20

new_game_plus=0

game_finished=false
level_finished=false
level_finished_t=0

level_next_level=false
level_t=0
cam_trans_s=1

--
function circles_new_level()
 player_reset()
 pickups_reset()
 
 srand(new_game_plus+current_level/100)
 
 circles={}
 
 level_radius=1024
 
 is_boss_level=current_level%5==0

 if is_boss_level then
  boss_level=current_level/5
  max_boss_health=20+boss_level*20
  boss_health=20+boss_level*20
 end

 start_circle=circles_add(0,0,16,0)
 start_circle.obstacle_count=0
 add(circles,start_circle)
 start_circle.last_circle=nil

 local last_circle=start_circle

 for i=1,10+current_level do
  local circle=nil
  while circle==nil do
   local a=rnd()
   local r=rnd(level_radius)
   circle=circles_add(r*cos(a),r*sin(a),16+rnd(24),i)
  end
  
  -- make pickups
  if not is_boss_level then
   circle.pickup_count=8
   local ap=0
   for i=1,circle.pickup_count do
    local r=circle.r-5
    local x,y=circle.x+r*cos(ap),circle.y+r*sin(ap)
    pickups_spawn(x,y,ap,circle)
    ap+=1/8
   end
  end
  
  add(circles,circle)
  circle.last_circle=last_circle
  last_circle=circle
  
  local colors=bg_colors_tables[mid(1,current_level,#bg_colors_tables)]
  local c,bc=colors[#colors],5
  
  local x,y=transform(circle,cam_matrix)
  --explosions_spawn(px,py,t,intensity,s,ds,count,c,bc)
  explosions_spawn(x,y,.5,4,6,-.2,20,c,bc)
 end
 
 pickups_total=pickups_active_count
 
 current_circle=start_circle
 objective_circle=nil
 
 goal_circle=circles[#circles]
 goal_circle.obstacle_count=0
 goal_circle.is_bumper=false
 goal_circle.is_moving=false
 
 if is_boss_level then
  -- if we're on a boss level, the goal circle becomes the boss
  -- acts like a bumper, 10 hits and it jumps to the next circle until boss_health is zero
  circle_add_boss(goal_circle)
 end
end

--
function circles_new_title_level()
 player_reset()
 pickups_reset()
 
 srand(0)
 
 circles={}
 
 level_radius=1024
 
 is_title_level=true
 is_boss_level=false

 start_circle=circles_add(0,0,32,0)
 start_circle.obstacle_count=0
 add(circles,start_circle)
 start_circle.last_circle=nil

 local last_circle=start_circle
 
 pickups_total=0
 
 current_circle=start_circle
 
 goal_circle=start_circle
end

--
function circles_find_closest(x,y,r)
 local closest_circle=nil
 local closest_distance=level_radius
 
 for k,v in pairs(circles) do
  local nx,ny,m=normalize(v.x-x,v.y-y)
  local distance=m-v.r-r
  if distance<closest_distance then
   closest_distance=distance
   closest_circle=v
  end
 end
 
 return closest_circle
end

--
function circle_add_obstacle(circle)
 local max_obstacle_count=min(8,.5+current_level/2)
 local max_moving_chance=max(0,.8*current_level/20)
 local max_bumper_chance=max(0,.6*current_level/20)
 local max_expanding_chance=max(0,.4*current_level/20)
 
 --[[circle type]]
 circle.obstacle_count=flr(rnd(max_obstacle_count))
 circle.is_moving=rnd()<max_moving_chance
 circle.is_bumper=rnd()<max_bumper_chance
 circle.is_expanding=rnd()<max_bumper_chance
 
 circle.base_obstacle_r=(.3+rnd(.4))*circle.r/circle.obstacle_count
 circle.obstacle_r=circle.base_obstacle_r
 
 local single_static=not circle.is_moving and circle.obstacle_count==1
 local a=0
 for i=1,circle.obstacle_count do
  local ca=circle.ot+a
  local r=single_static and 0 or circle.r/3
  circle.mx[i],circle.my[i]=r*cos(ca),r*sin(ca)
  local r=single_static and 0 or circle.r/3*cam_s
  circle.dx[i],circle.dy[i]=r*cos(ca+cam_a),r*sin(ca+cam_a)
 
  a+=1/circle.obstacle_count
 end
 --]]
end

--
function circle_add_boss(circle)
 
 --[[circle type]]
 circle.obstacle_count=boss_level
 circle.is_moving=true
 circle.is_bumper=true
 circle.is_boss=true
 circle.is_expanding=true
 
 circle.base_obstacle_r=.8*circle.r/circle.obstacle_count
 circle.obstacle_r=circle.base_obstacle_r
 
 --common function:
 local single_static=not circle.is_moving and circle.obstacle_count==1
  local a=0
  for i=1,circle.obstacle_count do
   local ca=circle.ot+a
   local r=single_static and 0 or circle.r/3
   circle.mx[i],circle.my[i]=r*cos(ca),r*sin(ca)
   local r=single_static and 0 or circle.r/3*cam_s
   circle.dx[i],circle.dy[i]=r*cos(ca+cam_a),r*sin(ca+cam_a)
  
   a+=1/circle.obstacle_count
  end
 --]]
end

--
function circles_add(x,y,r,i)
 if #circles>0 then
  -- find closest circle
  local last_closest_circle=nil
  local closest_circle=circles_find_closest(x,y,r)
  
  local iter_count=0
  while last_closest_circle!=closest_circle and iter_count<20 do
   local nx,ny,m=normalize(closest_circle.x-x,closest_circle.y-y)
   local distance=closest_circle.r+r-4-rnd(2)
   x=closest_circle.x-nx*distance
   y=closest_circle.y-ny*distance
   
   last_closest_circle=closest_circle
   closest_circle=circles_find_closest(x,y,r)
   iter_count+=1
  end
  
  if iter_count>=20 then
   return nil
  end
 end

 local circle={x=x,y=y,mx={},my={},dx={},dy={},r=r,i=i,obstacle_count=0,obstacle_r=0,boss_damaged_t=0,bumped_t=0,ot=i/8}

 if not is_boss_level then
  circle_add_obstacle(circle)
 end
 
 return circle
end

--
function circles_check_collision(entity)
 local inside_circle=nil
 for k,circle in pairs(circles) do
  local cx,cy=circle.x,circle.y
  local dx,dy=entity.x-cx,entity.y-cy
  local m=mag(dx,dy)
  
  if m>0 and m<circle.r then
   if inside_circle then
    -- inside two circles, we're safe to roam out of one
    return false,0,0,0
   else
    inside_circle=circle
   end
  end
 end
 
 -- we're inside one circle
 if inside_circle then
  current_circle=inside_circle
 end
 
 local cx,cy=current_circle.x,current_circle.y
 local dx,dy=cx-entity.x,cy-entity.y
 local nx,ny,mag=normalize(dx,dy)
 if mag>current_circle.r-player.radius then
  mag=current_circle.r-player.radius
  entity.x,entity.y=cx-nx*mag,cy-ny*mag
   
  return true,nx,ny,m
 end
 
 return false,0,0,0
end


--
function circles_check_obstacles(entity)
 local hit=false
 local anx,any=0,0
 
 if is_boss_level then
  if boss_health<=0 then
  return false,0,0
  end
 end
 
 for i=1,current_circle.obstacle_count do
  local cx,cy=current_circle.x,current_circle.y
  
  cx+=current_circle.mx[i]
  cy+=current_circle.my[i]
  
  local dx,dy=cx-entity.x,cy-entity.y
  local nx,ny,mag=normalize(dx,dy)
  if mag<current_circle.obstacle_r+player.radius then
   mag=current_circle.obstacle_r+player.radius
   entity.x,entity.y=cx-nx*mag,cy-ny*mag
   anx+=nx
   any+=ny
   hit=true
   
   if is_boss_level and i==1 then
    
    current_circle.boss_damaged_t=.2
    current_circle.obstacle_r-=(current_circle.base_obstacle_r/2)/10
    
    arrow_disabled_t=5
    
    if current_circle.obstacle_r<current_circle.base_obstacle_r/2 then
     current_circle.obstacle_count=0
     current_circle.boss_damaged_done=true
     
     local ex,ey=transform(current_circle,cam_matrix)

     if current_circle.last_circle!=nil then
      current_circle.is_boss=false
      circle_add_boss(current_circle.last_circle)
      
      --big explosion
      --explosions_spawn_uniform(px,py,t,intensity,s,ds,count,c,bc)
      explosions_spawn_uniform(ex,ey,1,16,8,-.2,16,11,8)
      screenshake(3,.2)
--     else
--      --big explosion
--      --explosions_spawn_uniform(px,py,t,intensity,s,ds,count,c,bc)
--      explosions_spawn_uniform(ex,ey,1,14,16,-.3,20,11,8)
--      screenshake(3,.2)
     end
    else
     boss_health-=1
     
     local ex,ey=transform(current_circle,cam_matrix)
     
     if boss_health<=0 then
      current_circle.is_boss=false
      --big explosion
      --explosions_spawn_uniform(px,py,t,intensity,s,ds,count,c,bc)
      explosions_spawn_uniform(ex,ey,1,14,16,-.3,20,11,8)
      screenshake(3,.2)
     else
      --small explosion
      --explosions_spawn(px,py,t,intensity,s,ds,count,c,bc)
      explosions_spawn(ex,ey,.5,3.5,8,-.4,16,11,8)
      screenshake(2,.1)
     end
    end
   end
  end
 end
 
 if hit then
  anx,any=normalize(anx,any)
  return true,anx,any
 end
 
 return false,0,0
end

--
function is_exit_active()
 if is_boss_level then
  return boss_health<=0
 else
  return pickups_active_count<=0
 end
end

--
function closest_objective()
 
 local closest_circle=nil
 local closest_distance=1000
 
 for k,circle in pairs(circles) do
  if circle.is_boss then
   return circle
  end
  
  if circle.pickup_count and circle.pickup_count>0 then
   local dx,dy=circle.x-current_circle.x,circle.y-current_circle.y
   local nx,ny,m=normalize(dx,dy)
   if m<closest_distance then
    closest_distance=m
    closest_circle=circle
   end
  end
 end
 
 if closest_circle==nil then
  -- check for boss and then for exit
  
  return goal_circle
 end
 
 return closest_circle
end

--
function circles_update()
 arrow_disabled_t=max(0,arrow_disabled_t-one_frame)
 
 level_t=min(2,level_t+one_frame)
 
 if not is_title_level then
  if level_t<=1 then
   if level_t>=.5 then
    if level_next_level then
     level_next_level=false
     current_level=next_level
     circles_new_level()
     game_save()
    end
   
    cam_trans_s=1+(1-(level_t-.5)/.5)*40
   else
    cam_trans_s=1+(level_t/.5)*40
   end
  else
   if level_finished then
    cam_trans_s=2+1*sin(t()*.75)
   else
    if is_boss_level then
     cam_trans_s=1.2
    else
     cam_trans_s=1
    end
   end
  end
 end
 
 for k,circle in pairs(circles) do
  circle.bumped_t=max(0,circle.bumped_t-one_frame)
  circle.boss_damaged_t=max(0,circle.boss_damaged_t-one_frame)
  
  local a=circle.is_moving and t()/10 or 0
  
  local single_static=not circle.is_moving and circle.obstacle_count==1
  local expanding_r=circle.is_expanding and circle.r/6*sin(t()/4) or 0

  for i=1,circle.obstacle_count do
   local ca=circle.ot+a
   local r=single_static and 0 or circle.r/3+expanding_r
   circle.mx[i],circle.my[i]=r*cos(ca),r*sin(ca)
   local r_cam=r*cam_s
   circle.dx[i],circle.dy[i]=r_cam*cos(ca+cam_a),r_cam*sin(ca+cam_a)
  
   a+=1/circle.obstacle_count
  end
 end
 
 objective_circle=closest_objective()

 if objective_circle==current_circle then
  arrow_disabled_t=5
 end
end

--
function draw_circle_text(text,x,y,wave)
 local blink=t()%.4>.2

 for j=0,#text do
  local row=text[j]
  for i=0,#row do
   local cs=row[i]
   if cs!=0 then
    local a=cam_a+.375+.8*i/#row
    local r=cam_s*(28+3*j)*.7
    if(wave)r+=8*sin(t()*.5+i/#row+j/#text*.1)
    local ox,oy=r*cos(a),r*sin(a)
    circfill(x+ox,y+oy,3,blink and 2 or c)
   end
  end
 end

 for j=0,#text do
  local row=text[j]
  for i=0,#row do
   local cs=row[i]
   if cs!=0 then
    local a=cam_a+.375+.8*i/#row
    local r=cam_s*(28+3*j)*.7
    if(wave)r+=8*sin(t()*.5+i/#row+j/#text*.1)
    local ox,oy=r*cos(a),r*sin(a)
    circfill(x+ox,y+oy,2,7)
   end
  end
 end
end

--
function circles_draw()
 local draw_circs={}
 
 local px,py=transform(player,cam_matrix)

 for k,circle in pairs(circles) do
  local x,y=transform(circle,cam_matrix)
  add(draw_circs,{x=x,y=y,r=circle.r*cam_s,obs_r=(circle.obstacle_r+circle.obstacle_r*.5*circle.bumped_t*5)*cam_s,c=circle})
 end
 
 local colors=bg_colors_tables[mid(1,current_level,#bg_colors_tables)]

 local c,bc=colors[#colors],5
 
 for k,dc in pairs(draw_circs) do
  circ(dc.x,dc.y,dc.r+4,bc)
  circ(dc.x,dc.y,dc.r+3,bc)
 end

 for k,dc in pairs(draw_circs) do
  circ(dc.x,dc.y,dc.r+2,c)
  circ(dc.x,dc.y,dc.r+1,c)
  circ(dc.x,dc.y,dc.r,c)
 end
 
 fillp(0b0101101001011010)
 for k,dc in pairs(draw_circs) do
  circfill(dc.x,dc.y,dc.r-1,0x10)
 end
 fillp()

 --[[]]
 local exit_active=is_exit_active()
 
 for k,dc in pairs(draw_circs) do
  local s=dc.r*.5
  
  if dc.c.boss_damaged_done then
   circ(dc.x,dc.y,s*.25+2,8)
   circ(dc.x,dc.y,s*.25,8)
  end
  
  if dc.c==start_circle then
   circ(dc.x,dc.y,s,7)
   circ(dc.x,dc.y,s-2,7)
  elseif dc.c==goal_circle then
   if exit_active then
    s=dc.r*.5+2*sin(t())
    circfill(dc.x,dc.y,s,0)
   end
  
   circ(dc.x,dc.y,s,10)
   circ(dc.x,dc.y,s-2,10)
   
   if exit_active then
    print_outline("exit",dc.x+1,dc.y-2,7,5)
   end
  end
 end 
 --]]

 -- draw obstacles
 local draw_bumpers=not is_boss_level or boss_health>0
  
 if draw_bumpers then
  for k,dc in pairs(draw_circs) do
   local circle=dc.c
   
   for i=1,circle.obstacle_count do
    local x,y=dc.x+circle.dx[i],dc.y+circle.dy[i]
    local bc=circle.is_bumper and (is_boss_level and 11 or 8) or circle.is_moving and 13 or 5
    local s=dc.obs_r
    circfill(x,y,s+1,bc)
    
    if circle.is_bumper then
     circ(x,y,s+3,bc)
    end
   end
   
   for i=1,circle.obstacle_count do
    local x,y=dc.x+circle.dx[i],dc.y+circle.dy[i]
    
    local c,bc=13,5
    if is_boss_level then
     c,bc=3,11
    elseif circle.is_bumper then
     c,bc=7,8
    elseif circle.is_moving or circle.is_expanding then
     c,bc=12,13
    end
    
    local s=dc.obs_r
    
    circfill(x,y,s,c)
   end
  
   -- draw boss's eye
   if is_boss_level and boss_health>0 and circle.obstacle_count>0 then
    local x,y=dc.x+circle.dx[1],dc.y+circle.dy[1]
     
    local c,bc=3,11
    local s=dc.obs_r
    
    if circle.boss_damaged_t>0 then
     line(x-s/3,y,x+s/3,y,bc)
    else
     circfill(x,y,s/2,7)
     local nx,ny,m=normalize(x-px,y-py)
     circfill(x-s/5*nx,y-s/5*ny,s/5,0)
    end
   end
   
   -- draw title screen
   if is_title_level or game_finished then
    local x,y=dc.x,dc.y
    draw_circle_text(title_text,x,y,game_finished)
   end
  end
 end
 
 local x,y=transform(current_circle,cam_matrix)
 if is_title_level or game_finished then
  -- draw title screen
  draw_circle_text(title_text,x,y,game_finished)
 else
  if arrow_disabled_t<=.25 then
   if objective_circle and objective_circle!=current_circle then
    local ox,oy=transform(objective_circle,cam_matrix)
    local dx,dy=ox-x,oy-y
    local nx,ny,m=normalize(dx,dy)
    
    local r=(current_circle.r+4)*cam_s+4*sin(t())
    
    arrow.tx,arrow.ty=x+r*nx,y+r*ny
    arrow.nx,arrow.ny=nx,-ny
    arrow.scale=.8*(1-mid(0,arrow_disabled_t*4,1))
    
    local color=t()%.4>.2 and 11 or 3
    
    if is_boss_level and boss_health>0 then
     color=t()%.4>.2 and 11 or 8
    elseif objective_circle==goal_circle then
     color=t()%.4>.2 and 7 or 10
    end
   
    arrow.draw(color)  
   end
  end
 end
end

--
function scan_text(text)
  scan={}
  rectfill(0,0,#text*4+1,7,0)
  print(text,0,0,1)
  for y=0,7 do
    scan[y]={}
    for x=0,#text*4+1 do
      scan[y][x]=pget(x,y)
    end
  end
  return scan
end

title_text=scan_text("pinballvania!")

--
pickups={}

for i=1,400 do
 add(pickups,{active=false})
end

--
function pickups_reset()
 for k,pu in pairs(pickups) do
  pu.active=false
 end

 pickups_next,pickups_active_count,pickups_total=1,0,0
end

--
function pickups_spawn(x,y,ap,circle)
 local pu,i=find_next_i(pickups,pickups_next,pickups_active_count)

 if pu then
  pickups_next=i
  pickups_active_count+=1
  
  pu.active,pu.t,pu.x,pu.y=true,ap,x,y
  pu.circle=circle
 end
end

--
function pickups_update()
 for k,pu in pairs(pickups) do
  if pu.active then
   pu.t+=one_frame
 
   --check collisions with the player
   local pux,puy=pu.x,pu.y
   local px,py=player.x,player.y
   if abs(px-pux)<=8 and abs(py-puy)<=8 then
    pu.circle.pickup_count-=1
    pu.active=false
    pickups_active_count-=1
    local pucx,pucy=transform(pu,cam_matrix)
    explosions_spawn_uniform(pucx,pucy,.5,4,6,-.3,8,11,8)
    
    arrow_disabled_t=5
    sfx(7,3)
   end
  end
 end
end

--
function pickups_draw()
 for k,pu in pairs(pickups) do
  if pu.active then
   local pux,puy=transform(pu,cam_matrix)
   local s=(2+sin(pu.t))*cam_s
   circfill(pux,puy,s+1,3)
   circfill(pux,puy,s,11)
  end
 end
end

--
function ui_update()
 if(game_saved>0)game_saved-=one_frame
 
 if is_title_level or level_finished then
  level_finished_t+=one_frame
 
  if level_finished_t>1 and (btnp(2) or mouse_up) then
   if is_title_level then
    is_title_level=false
    next_level=current_level
   else
    if game_finished then
     new_game_plus+=1
     next_level=1
     game_time=0
    else
     next_level=min(max_level,current_level+1)
    end
   end

   sfx(10,1)
   level_next_level=true
   level_finished=false
   game_finished=false
   level_t=0
   arrow_disabled_t=5
  end
 end
end

--
function ui_draw()
 if is_title_level then
  print_outline("<press up to start>",64,112,7,t()%.4>.2 and 8 or 0)
  print_outline("cveinnt & guerragames",64,120,7,0)
 elseif game_finished then
  print_outline("good job! game finished!",64,64+32,7,0)
  print_outline("brag about it on the webs!",64,64+32+8,7,0)
  
  local ngs=""
  if(new_game_plus>0)ngs=""..(new_game_plus+1)
  print_outline("<press up for ng+"..ngs..">",64,64+32+16,7,0)
 elseif level_finished then
  print_outline("level finished!",64,64+32,7,0)
  print_outline("<press up to continue>",64,64+32+8,7,0)
 end
 
 if game_saved>0 and game_saved%.2>.1 then
  print_outline("game saved",64,120,7,0)
 end
 
 local exit_active=is_exit_active()
 
 local c,bc=7,0
 if not is_title_level and exit_active and t()%.4>.2 then
  c,bc=0,10
 end
 
 print_outline((pickups_total-pickups_active_count).."/"..pickups_total,2,2,c,bc,align_l)
 print_outline(time_to_text(game_time),64,2,c,bc)
 
 local ngs=""
 if(new_game_plus>=1)ngs=new_game_plus.."."
 print_outline("lvl:"..ngs..current_level,127,2,c,bc,align_r)
 
 if is_boss_level then
  rect(2,9,125,19,7)
  local l_health=boss_health/max_boss_health*119
  if(l_health>=1)rectfill(4,11,4+l_health,17,8)
 
  print("boss",5,12,7)
 
 end
end

--
background_iter_count=50

--
function rndb()
 return 64-rnd(128)
end

--
function background_splatters(colors)
 for i=0,background_iter_count do
  local x,y=rndb(),rndb()
  local c=pget(x,y)
  
  local nx,ny,m=normalize(x,y)
  line(x,y,x+8*nx,y+8*ny,c)
  circfill(x+8*nx,y+8*nx,rnd(3),colors[flr(rnd(#colors))+1])
 end
end

--
function background_sphere(colors)
 for i=0,background_iter_count do
  local x,y=rndb(),rndb()
  local nx,ny,m=normalize(x,y)
  local s=min((128-m)/26,4)
  circfill(x,y,s,colors[flr(rnd(#colors))+1])
  circ(x,y,s,0)
 end
end

--
function background_linesandbubbles(colors)
 for i=0,background_iter_count do
  local x,y=rndb(),rndb()
  local c=pget(x,y)
  
  local nx,ny,m=normalize(x,y)
  line(0,0,128*nx,128*ny,c)
  circ(x,y,rnd(8),colors[flr(rnd(#colors+1))+1])
 end
end

--
function background_spiral(colors)
 for i=0,background_iter_count do
  local x,y=rndb(),rndb()
  local c=pget(x,y)
  local r=sqrt(x*x+y*y)
  local a=atan2(x,y)+r/128+t()/40
  
  local nx,ny,m=normalize(x,y)
  line(x,y,x+8*cos(a),y+8*sin(a),colors[flr(rnd(#colors+1))+1])
 end
end

--
function background_circles(colors)
 for i=0,background_iter_count do
  local x,y=128-rnd(256),128-rnd(256)
  circ(x,y,rnd(32),0)
  circ(0,0,x,colors[flr(rnd(#colors+1))+1])
 end
end

--
function background_blocks(colors)
 for i=0,background_iter_count do
  local color=colors[flr(rnd(#colors+1))+1]
  local r,dr=rnd(256),12
  local a,da=rnd(),.025
  local r1,r2=r+dr,r-dr
  local a1,a2=a+da,a-da
  local ca1,sa1,ca2,sa2=cos(a1),sin(a1),cos(a2),sin(a2)
  line(r1*ca1,r1*sa1,r2*ca1,r2*sa1,color)
  line(r1*ca2,r1*sa2,r2*ca2,r2*sa2,color)
  line(r1*ca1,r1*sa1,r1*ca2,r1*sa2,color)
  line(r2*ca1,r2*sa1,r2*ca2,r2*sa2,color)
 end
end

--
function background_bubbles(colors)
 for i=0,background_iter_count/5 do
  local x,y=rndb(),rndb()
  local r=2+rnd(8)
  circfill(x,y,r,colors[1])
  circfill(x,y,3*r/4,colors[2])
  circfill(x,y,r/2,colors[3])
  circfill(x,y,r/4,colors[4])
 end
end

--
function background_drip(colors)
 for i=0,background_iter_count do
  local x,y=rndb(),rndb()
  local c=colors[flr(rnd(#colors+1))+1]
  local nx,ny,m=normalize(x,y)
  line(x,y,x+8*nx,y+8*ny,c)
 end
end

--
function background_rainbow_splat(colors)
 for i=0,background_iter_count do
  local x,y=rndb(),rndb()
  local nx,ny,m=normalize(x,y)
  local c=colors[flr((m/8+t()/5)%#colors)+1]
  circfill(x,y,rnd(4),c)
 end
end

--
function background_rainbow_spiral(colors)
 for i=0,background_iter_count do
  local x,y=rndb(),rndb()
  local nx,ny,m=normalize(x,y)
  local a=atan2(nx,ny)
  local c=colors[flr((a*4*#colors+m/12-t()/10)%#colors)+1]
  circfill(x,y,rnd(3),c)
 end
end

--
function background_text(colors)
 local strs={"pico8","guerragames","pinballvania",}
 for i=0,background_iter_count do
  local x,y=128-rnd(256),128-rnd(256)
  local c=colors[flr(rnd(#colors+1))+1]
  rectfill(x,y,x+4,y+6,0)
  print(strs[flr(rnd(#strs))+1],flr(x/4)*4,flr(y/6)*6,c)
 end
end

--
function background_fire(colors)
 local time=t()/50
 for i=0,background_iter_count do
  local x,y=rndb(),rndb()
  local nx,ny,m=normalize(x,y)
  local a=atan2(nx,ny)
  local c=colors[flr((sin(m/32+time)+cos(a*3+time)+time*5)%#colors)+1]
  circfill(x,y,1,c)
 end
end

--
function background_star(colors)
 local time=t()/80
 for i=0,background_iter_count do
  local x,y=rndb(),rndb()
  local nx,ny,m=normalize(x,y)
  local a=atan2(nx,ny)
  local c=colors[flr(max(0,sin(m/16-time+m/128*cos(a*5+time/5)))*#colors)+1]
  circfill(x,y,1,c)
 end
end

--
function background_whitenoise(colors)
 for i=0,background_iter_count do
  local x,y=rndb(),rndb()
  local c=colors[flr(rnd(#colors+1))+1]
  
  if rnd()>.5 then
   line(x,y,x,y+5,c)
  else
   line(x,y,x+5,y,c)
  end
 end
end

--
function background_swirl(colors)
 local time=t()/80
 for i=0,background_iter_count do
  local x,y=rndb(),rndb()
  
  local nx,ny,m=normalize(x,y)
  local a=atan2(nx,ny)+time
  local c=pget(x,y)
  line(x,y,x-m*.2*cos(a),y-m*.2*sin(a),c)
  if c==0 then
   local c=colors[flr(rnd(#colors+1))+1]
   pset(x,y,c)
  end
 end
end

--
function virus_function(x,y)
v=1
for i=-1,1 do
for j=-1,1 do
if(pget(x+i,y+j)!=0)v+=1
end
end
return v
end

--
function background_virus(colors)
 for i=0,background_iter_count do
  local x,y=rndb(),rndb()
  local v=virus_function(x,y)
   
  pset(x,y,colors[v])
  if rnd()>.9995 then
   circfill(rndb(),rndb(),rnd(24),0)
  end
 
  if rnd()>.999 then
   local c=colors[#colors]
   local n,m=rndb(),rndb()
   if(pget(n,m)==0)circfill(n,m,rnd(4),c)
  end
 end 
end

--
function background_maps(colors)
 local time=t()/40
 for i=0,background_iter_count do
  local x,y=rndb(),rndb()
  local r=abs(4*sin(time))
  rectfill(x-r,y-r,x+r,y+r,pget(x,y))
  if rnd()>.99 then
   local c=colors[flr(rnd(#colors+1))+1]
   rectfill(x-r,y-r,x+r,y+r,c)
  end
 end
end

--
function background_cthulhu(colors)
 local time=t()/160
 for i=0,background_iter_count do
  local x,y=rndb(),rndb()
  local a=atan2(x,y)+time/8
  local r=sqrt(x*x+y*y)/256*sin(time)
  local aa=time+sin(a)
  circfill(x,y,1,16*(r+a+aa)%4)
 end
end

--
function background_furryspiral(colors)
 local time=t()/160
 for i=0,background_iter_count do
  local x,y=rndb(),rndb()
  local g=time-sin(time)-atan2(x,y)
  line(x,y,x+6*sin(g),y+6*cos(g),16*(sqrt(x*x+y*y)/128-g)%4)
 end
end

--
function background_blood(colors)
 if(rnd()>.95) then
  local x,y=rndb(),rndb()
  circfill(x,y,2+rnd(6),rnd()>.4 and 8 or 0)
 end
 
 for i=0,background_iter_count do
  local x,y=rndb(),rndb()
  if pget(x,y)!=8 then
   circ(x,y,1,0)
  else
   line(x,y+1,x,y+rnd(8),8)
  end
 end
end

--
bg_colors_tables={
{0,5,4},
{1,5,13},
{0,12,13},
{0,11,3},
{0,8},
{0,5,6,7},
{0,1,13,12},
{0,0,0,0,12,13,7},
{6,7,8,9,10,11,12,13,14},
{0,8,9,10,7,10,9,8},
{0,5,6,7},
{8,9,10,11,12,13,14},
{0,9,10,7,10,9},
{0,7,6},
{0,1,2,12,13,8},
{0,1,2,2,8,8,3,3,11,11},
{9,10,11,12},
{0,1,2,3},
{0,1,3,2},
{0,8},
}

--
bg_function_table=
{
 background_splatters,
 background_sphere,
 background_circles,
 background_spiral,
 background_linesandbubbles,
 background_blocks,
 background_bubbles,
 background_drip,
 background_rainbow_splat,
 background_fire, 
 background_text,
 background_rainbow_spiral,
 background_star,
 background_whitenoise,
 background_swirl,
 background_virus,
 background_maps,
 background_cthulhu,
 background_furryspiral,
 background_blood,
}

--
function background_draw()
 memcpy(0x6000,0x0,0x2000)

 background_iter_count=cpu<.9 and 50 or 20
  
 local colors=bg_colors_tables[mid(1,current_level,#bg_colors_tables)]
 local back_function=bg_function_table[mid(1,current_level,#bg_function_table)]

 back_function(colors)

 memcpy(0x0,0x6000,0x2000)
end

--
function _init()
 music(0,0,3)
 game_load()
 menuitem(1,"reset progress?!",game_reset)
 
 memcpy(0x0,0x6000,0x2000)
 circles_new_title_level()
end

--
function _update60()
 one_frame=1/stat(8)
 
 if(not is_title_level and not level_finished)game_time+=one_frame
 
 update_screeneffects()
 
 cam_update()
 
 circles_update()

 pickups_update()
 player_update()
 
 parts_update()
 
 ui_update()
end

--
function _draw()
 camera(cam_shake_x-64,cam_shake_y-64)
 
 background_draw()


 circles_draw()

 pickups_draw()
 
 parts_draw()
 player_draw()
 
 camera(0,0)
 ui_draw()
 
 cpu=stat(1)

 --[[stats and debug
 pal()
 color(7)
 y=122

 print("mem:"..stat(0),1,y)y-=6
 print("cpu:"..cpu,1,y)y-=6
 print("arrow.dis:"..arrow_disabled_t,1,y)y-=6
 
 --]]
end

__gfx__
77707770770077707770700070007070777077007770777000000000000000000000000000000000000000000000000000000000000000000000000000000000
70700700707070707070700070007070707070700700707000000000000000000000000000000000000000000000000000000000000000000000000000000000
77700700707077007770700070007070777070700700777000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000700707070707070700070007770707070700700707000000000000000000000000000000000000000000000000000000000000000000000000000000000
70007770707077707070777077700700707070707770707000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
15554444444001000055500444011055500400000500404044400404055554050050450004044440550050544441550505544400000050045550400550444000
00000000000000000005450004015040500044050500404044400000054000000000555000004440050000444414055055454000400000000000005544000000
00777000707770000004455041501540000044050500444444407770000077707770450077705440000500444414555045444004000705070707055000077004
50707007007070000010555511051550000040555544444444507070070070707070450070700454000044454414550055540044500705070707044070007045
50707007007070000010454511554455000400555554444444507070000070707070054070704555004044454140550050444045050704070707044000407055
50707007007070000444444455555055444400555554444440407070070070707070000070705450000444551105540555450405500700077707000070007005
50777070007770054444444445505044554440555554544440407770000077707770070077704440000544551555500554444055500777007007770000077700
50000000000000404444444444505504545440055500454440400000550000000000000000004400004445501055005555400054400000000000000044000004
05555500004444444444444444055555555440000000444444455555555450050000555500d54401004005511555405555500544404000544550040005575040
50455500000444444444444445504445555540000000444544045555555550505555555000054400040050515555045445405544444000044540000455750450
54445550000044444444444444004444455555500000045554045555555040505550055000000000040555015555054454055444440000044000000447000000
40405555444004444455544444440444455555500001054544444505554000505550405000000000055545155505054555000544400000040000004474050004
04440554444404444555554404440444505555550501054444444000444440105540444040050000505555155000054044400540055000400540040740000044
04440054444440444555555544444045005500050500145004444405444044401d40444d40050005505551555505544444404444005d0d005404007455050444
40400004444400444555555544444000000000005055115d04444444544044401d4044454015400500555145544444444404445000d040400040574500504444
040000004444000444555055540440000000000055555145404444445040444010000455405544555005544454444444440444500d4404000005755555445444
000000050050400004044505555000000000000055550510004444444055555555555550405544550005400044444440404444040d0005000007555549454455
000000005005540045405550555500000005000555550000000445555555555555555555555544500405000044444405504440555d00540000070d5495550555
0054400005454440045405050d50000000505505555551000555555555444444444444455555555504550000444444040500055000054900007d544955555555
0404444000044444004045404455040d000054555555550555555444444444444444444444445555555000000444004444400000000400507755455504540555
54000405000444440004044404545540000000505555555550444444444444444444444444444440555550004400004444440000000045775554554055055455
44404444440444445000444400445550044440055555555444444444441010101010101444444444445555544000000454444000000555705040544550500044
44444444444044444554044000045504444444455555544444444101010101010101010101014444444445555000000544444400005057000404455505000054
44444444444505554455455550000500444444555554444444101010101010101010101010101014444444050515105144404059950570054045555550000000
44044444444455505445555555000550444445555444444401010101010101010101010101010101004444445555105100555559505704555455555500000000
44400004444050555544455555500055544455544444401010101010101010101010101010101010101044444451554044455495057964554055550000450000
54444400554455555544455555070065444555404441010101010101010101010101010101010101010101444045550044054955776040640555500000005050
55444440555404555544445555050004555504444010101010101010101010101010101010101010101010114444455540504557444005505005040000055555
40444440555544455004444455470000555444040101010101010101010101010101010101010101010101010414445455545574444405000055540000050050
04444440505555444550454005547775054444401010101010101010101010101010101010101010101010101044444545457744444055500045450000500555
00044400055455555454045540554757544440010101010101010101010101010101010101010101010101010100444454575444000550050445500000005050
55004044015554555544400554050575444410101010101010101010101010101010101010101010101010101010145445454570040000544050000000055555
05000440541155555554440055405054474101010101010101010101010101010101010101010101010101010101014444555750400000440005000000555555
55444004454415555554444005550544741222101010101010101010101010101010101010101010101010101010101444457540000004400000400045555504
55054500544441055544445555555441412777210101010101010101010101010101010101010101010101010101010144445544040545400000000000555455
55400444444444115004055000554144127777721010101010101010101010101010101010101010101010101010222014444554545544400000000004445555
55044505405444411000450005504441027777772101010101010101010101010101010101010101010101010102777201444555544445450005000004445444
55004440444554545105550050544450127777777210101010101010101010101010101010101010101010101027777720044454554544554540000005444444
55500454454455444551150055444401012777777721010101010101010101010101010101010101010101012227777721040445554444550444000044444444
05000554444044444405545554044010101277777772101010101010101010101010101010101010101010127777777720104454550545000040000444444444
00000444444004444450445454440101010127777777210101010101010101010101010101010101010102277777777201010444505000000000044455544444
00003344444054444444545544441010101277777777721010101010101010101010101010101010101027777777222010101544455007700000444555554444
44440344444455444040455044410101010277777777772101010101010177777777710101010101010277777777210101010144445577740044444555554445
44404444444444550444055444101010102777777777777210101010177710101010177710101010102777777772101010101014445544504444444554445445
44444444444444444540550444010101027777772777777201010177710177777777710177710101027777777221010101222104444550447344444445554444
00004444444455544445554440222010127777777777777210101710177710101010177710171010127777772010101222777210444554737345554445544444
00000444554555554444554442777201027777777777772101077107710101010101010177017701027777720101022777777721444554444455555444444444
50005554445555557005544427777720102777777777721010701770101010101010101010771070102777201010277777777720444455444455555444444455
40005000004555555775544427777721010227777777210107017101010101010101010101017107010222010122777777777721044455444455555444455554
44550000400055554555744427777720101012277777201070171010101010101010101010101710701010122277777777777210144455547445554444055544
05555444000224440455444277777772220102227772010701710101010101010101010101010171070101277777777777222101014445544444400044455445
55550044440004422255444277777777772227772220107017101010101010101010101010101017107012777777777777201222104445544000000444445540
45555555000444444455444277777777777777777201017171010101010101010101010101010101717102777777777777222777214445500055544444444444
44550544555544455554441277777777777777777210171710101010101010101010101010101010171712777777777777777777721444555554444444000454
44444004044440044554442777777777777777777201710701010101010101010101010101010101070171277777777777777777720444554444444444505555
44444400004444444554442777772227777777772010707010101010101010101010101010101010107070277777777777777777721444554545555555500000
44444444045444444554442777772102227777772101717101010101010101010101010101010101017171027777777777777777210444550545555444550004
44500000444444445554441277721010102777772017171010101010101010101010101010101010101717127777777777777222101444550040554444444055
54444000045444445544410122210101012777772107070101010101010101010101010101010101010707027777777222222122210144455555555555550000
05555555550544405544401222101010102777772017171010101010101010101010101010101010101717102777222010101277721044455555555554400044
00000000075704445544412777222222222277720171710101010101010101010101010101010101010171710277720101012777772144455555555554440444
00074444000000405544427777777777777777201070701010101010101010101010101010101010101070702777772010102777772044455555555550004444
44000000444445555544427777777777777777720171710101010101010101010101010101010101010171712777772222222777772144455555455544444444
70007777777777775544427777777777777777721070701010101010101010101010101010101010101070702777777777777777721044455555554444444444
00000400000055555544412777777777777777720171710101010101010101010101010101010101010171712777777777777777772144455444444444444444
44444444444455555544401222777777777777721070701010101010101010101010101010101010101070702777777777777777772044455450000054444444
55554444400005555544410101222222777777720171710101010101010101010101010101010101010171712777777777777777772144455555000555050444
04544444444444405544401022277777777777201070701010101010101010101010101010101010101070702777777777777777721044455455000050000000
44444444000000055544410277777777777722010171710101010101010101010101010101010101010171712777772222227777720144455544444000555550
44444444000004555544402777777777777720101017171010101010101010101010101010101010101717101277721010127777721044455444444555555500
44444440400040545544412777777777777202220107070101010101010101010101010101010101010707010122220101027777720144455444044444445000
44444404444444055554442777777777722227772017171010101010101010101010101010101010101717101027772220102777201444554444444000005000
44444440000040044554440277722222227777777201717101010101010101010101010101010101017171012277777772220222010444554544444445550000
00000000004444400554441022202227777777777210707010101010101010101010101010101010107070127777777777772220101444550554144444444400
00040444444004444554440101227777777777777721710701010101010101055501010101010101070171277777777777777772010444552000444444444444
00000400004004411554441012777777777777777720171710101010101015566655101010101010171712777777777777777777201444550200044455544111
00000044544444440255444127777777777777777721017171010101010105666765010101010101717127777777227777777777214445500004004555554440
00000444444522222055444027777777777777777772107017101010101056667776501010101017107027777777722227777777204445500044404555554440
00044440552200000055444127777777777777777772010701710101010156666766510101010171070227777777777222227772014445550004004555554455
50005555222004004055044412777727777777777772201070171010101056666666501010101710702777777777777772102220144405555000004455544044
05555550445044450005544402777777777777777777720107017101010105666665010101017107027777722777777777220101044455555450554444404400
55555555544454550775544442777777777277722777772010701770101015566655101010771070127777777227777777772010544455555044455444004444
55555444445555077477554442777777777222227777777221077107710101055501010177017701277777777722777777777201444555054404555500044444
55554405550577757777554440277777777210277777777772101710177710101010177710171012777777777772227777777210444550004444554445544444
55000055057705777777550444027777772102777777777777210177710177777777710177710127777777777777212277777204444555554444454444444444
00455505770577477444455444127777721227777777777777222010177710101010177710122227777772777777721027772014445554544044004444544445
05544777007700044044455544412777212777777772777777777201010177777777710101277727777777777777772102220144455555555440440444444444
04477450004050004444455544401222127777777777777777777720101010101010101222777772777777777777777210101544455555555554444400444444
04444450040004004444545554440101277777777777777727777721010122210101012777777777277777777777777721010444505555055554444444004400
45444505500000444455444554544012777777777777777727777720101277721010127777777777727777777277777720104444555055555555544445440044
04444455500000445554404455441402777777227777777277777201012777772101027777777777727777772127777721040445505500555555555454454400
44444455500004555444000454544452777772127777772277777210102777772010127777727777722777777212777210444455500400555555055554004000
54444455550005544554405055524441277721027777722777777201012777772101027777722777772277777721222101444055550005554550505505500000
44444055555555455544444411554544122210277777722777772010102777772010127777722777772277777772101014454555555505544454445555550000
40400000055545455454444152755444410102777777227777772101012777772101027777772777777227777772010145445555505405554544444550550050
00000000550454444444444440750544441012777772277777721010102777772010102777777777777722777772101454450555000500555544444555505550
05000005000544444444444455555454474102777772277777210101012777772101012777777777777721277721014544575545500500455544444550000545
50000000005445544444444555544555444410277720277777201010102777772010101277777777777720122210145445055550004005555554445500005555
00000000004555444444444555455055544440022202777777722221012777772101010277777777777201010107444451505544040550555550444050000055
40000000005054454444444554550055554044401012777777777772102777772010101277777777772010101044454545455545444555005554024452044500
44000444555544541544455545504455505444040102777777777777212777772202220127772777772101010474445055445445544555550500000240000440
44444445555400045444445450444545055504444010277777777777202777777727772012222777772010124444455554544545554055555000005052044004
44440055555551444442454504445450454555444441022277777777227777777777777201010277720101444545554445454405504005054550002200400445
44005555555515444454445044454540544450544444401022227772127777777777777210101022201044444455544455544405550050400555000020004004
40055504555454440004050044544555544505555444444001012221027777777777777201010101044444445555745555554440555500045555544500550545
04050044445444400000500044445505555404450544444444101010102777277727772010101014444444455505074500005040050455555555555000055555
40000400054444500000500044440000554444005555444444444101010222022202220101014444444445555550074000000505005555555555555550005555
44000000045455400005000044400505554405040055555444444444441010101010101444444444445555545554044000000550400444555555555505004555
44400000444554040054000444000455544050500005555550444444444444444444444444444444555554445505007000004555444444455545555500544405
44400004445544404544004404004445404500000055550555555444444444444444444444445555555444444550500700044454444444455455555000055000
45550004055444044445044450505454040500000055500005555555554444444444444555555555454254045550440000554045444444455045500000000500
55555040055540444454454044088888888888888888888888000888888888555888888888550088888888888888888888884000544444555504440000000000
55555005450404444554445450887877787778777887788778000878787778555877788778000887787778777877787778788000044455555450444040000000
55555500504000445500450508878878787878788878887888040878787878455887887878740878888788787878788788878800054540445544444440000000
05555500540000455505500508788877787788778877787778000878787778454087887878040877788788777877888788887800044440044544444440005550
05555500400000550555000058878878887878788888788878000878787888455087887878540888788788787878788788878800444444004454444455500555
50555004540005555554440507887878587878777877887788000887787844455887887788044877888788787878788788788444444444400400444055555050
05000005454455555545444444488888488888888888888880000588888845055588888885544888848888888888888888884444444440000000444005555555
45000004545554555444444444440544444400550000584400004555155545055444455555504555405044558444444474440400444404400000044455544555
45000045455550554444400044404004000000000000000000000000000000000000000000004550000000000000000047445440404540000000004555045555
40000454555544444044000044440000077070707770777077707770077077707770777007704550777077707700777044755550044454000000400450005555
00004555555444444044000004440000700070707000707070707070700070707770700070004550007070700700707044475850004440000000544004000455
00040555555444440544000000440000700070707700770077007770700077707070770077704000777070700700777044474740004440400000444000000050
004055555504444444444000444e0000707070707000707070707070707070707070700000705000700070700700007044847400000444440000000500000055
00055555500e444e9444440444e00090777007707770707070707070777070707070777077004500777077707770407004404400000044400400000050000055
0c55555500c40cccc44c404444e0cc50000000000000000000000000000000000000000000044500000000000000400004404e40000e45440000000095000555
955555500e90cc9e4494044e4e009e55000045477e400e05454000444445555555444e0e4057544454444000544440000e440e90000404940400000055545555
955595009e0ccee44e44044e4e0e95750000454775400e45454704444045555555549e0440500045444445055444400075440e9e084000404040005505555455

__sfx__
01020000160730a07310073060530d033050130000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003
01020000160630a06310053060430d023050130000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003
01020000160430a04310033060330d023050130000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003
01020000160230a02310023060130d013050130000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000800040777004760027500574004720037200371003710037100170001700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
0004000018554215540b5441e54408534155240651407504065040050400504005040050400504005040050400504005040050400504005040050400504005040050400504005040050400504005040050400504
00020000115402b540335301d52014520095100b51009510105000650000500005002e50000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
00030000114610c45117451054411744109431154310942115421044210d411034110241100401004010040100401004010040100401004010040100401004010040100401004010040100401004010040100401
00030000103600c350203500534026340093301633009320193200432019310033100c3100b310003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
000700000b3140c3240f33413334183341c3441f34423344263442534425344233442864025640226401d6401864015640116400c640096400864005630066200362001610000000000000000000000000000004
0005000023314213241933412344183541c3641f36423364263542534425334233241e3241a33417344193541b3641e3642036422364203542634424334293242631401304003040030400304003040030400304
0007000023315213251933512335183351c3451f34523345263452534525335233251e3251a335173352c04531055370553905537055390553704539035370253901501605000050000500005000050000500005
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000001c7551c755007051c755217550070523755007051c7551c755007051c755237550070524755007051c7551c755007051c755247550070523755007051c7551c755007051c75523755007052175500705
011000001c333040701f3331c33321643040701c3331f3331c333040701f3331c33321643040701c3331f3331c333040701f3331c33321643040701c3331f3331c333040701f3331c33321643040701c3331f333
011000001c7551d7551f755040701f7552175504070217551c7551f755217550407021755237550407023755040702375524755217552475523755040701f75504070237551f755217551d7551f755040701d755
011000001c33321643216431c33321643216431c333216431c33321643216431c33321643216431c333216431c33321643216431c33321643216431c333216431c33321643216431c33321643040701c33321643
011000001c7551c755000051c755000051c75521755000051c7551c755000051c755217551c75523755000051c7551c755000051c755000051c75523755000051c7551c755000051c755237551c7552475500000
011000001c333040701f3331c33321643040701c3331f3331c333040701f3331c33321643040701c333216431c333040701f3331c33321643040701c3331f3331c333040701f3331c33321643040701c33321643
011000001c7551c7551d7551d7551f7551f75504070217551d7551d7551f7551f755217552175504070237551f7551f7552175521755237552375504070247552475523755217551f75523755217551f7551d755
011000001c333216431c3331c33321643216431c333216431c333216431c3331c33321643216431c333216431c333216431c3331c33321643216431c333216431c333216431c3331c33321643040701c33321643
011000002154521545005052354500505215452454500505215452154500505215452454521545265450050524545265450050524545005052654521545005052354524545005052354500505245452154500505
01100000090750907500000000000907509075000000000009075090750000000000090750907500000000002164321643090751c333216431c3331c333090752164321643090751c333216431c3331c33309075
011000002334524345003052334500300243452134500305233452434500305233452334524345213450030524345263450030524345003002634521345003002334524345003052334523345243452134500305
011000002164321643090751c33321643090751c333090752164321643090751c333216431c3331c333090752164321643090751c333216431c333090750907521643216430907509075216431c3331c33309075
011000002304524045000052304523045240450000023045230452404500005230452304524045210450000524045260450000524045240452604500000240452404526045000052404524045260452104500005
0110000021643216430907521643216431c3330907521643216431c3330907521643216431c333090750907521643216430907521643216431c3330907521643216431c3330907521643216431c3330907509075
01100000217451f745217450070023745217452374500700247452374524745237452474523745000000070023745217452374500000267452474526745000002874526745287452874529745287450000000000
01100000216431c3332164309075216431c3332164309075216431c3332164309075216431c3330000000000216431c3332164309075216431c3332164309075216431c3330907521643216431c3330000000000
__music__
01 16174344
00 14154344
00 1a1b4344
00 18194344
00 1c1d4344
00 1e1f4344
00 20214344
02 22234344

