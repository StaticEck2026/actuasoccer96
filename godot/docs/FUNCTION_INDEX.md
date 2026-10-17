# Function index: original C function -> GDScript module class

Call a function from another module as `<Class>.<func>(...)`; inside the same module call it unqualified.
Functions with C++ reference parameters (`&`) return an Array — see PORTING.md.

| C function | GDScript class | signature (original) |
|---|---|---|
| `matherr` | Maths | `int matherr(struct exception *)` |
| `af_randomize` | Maths | `void af_randomize()` |
| `random_vector` | Maths | `void random_vector(float &a,float &b)` |
| `rand_range` | Maths | `int rand_range(int range)` |
| `calc_dist` | Maths | `float calc_dist(float x,float y)` |
| `get_angle` | Ball | `float get_angle(float x,float y,float d)` |
| `get_xydis_from_ang` | Ball | `void get_xydis_from_ang(float a,float d)` |
| `get_s_angle` | Ball | `float get_s_angle(float z,float d)` |
| `get_zdis_from_ang` | Ball | `void get_zdis_from_ang(float a,float d)` |
| `stop_ball_spin` | Ball | `void stop_ball_spin()` |
| `swerve_xyz` | Ball | `void swerve_xyz()` |
| `inc_swerve` | Ball | `void inc_swerve()` |
| `get_aftert_spin` | Ball | `void get_aftert_spin()` |
| `add_spin_fx` | Ball | `void add_spin_fx()` |
| `move_ball` | Ball | `void move_ball()` |
| `grav_ball` | Ball | `void grav_ball()` |
| `ball_friction` | Ball | `void ball_friction()` |
| `roll_ball` | Ball | `void roll_ball()` |
| `ball_trajectory` | Ball | `void ball_trajectory()` |
| `get_ball_zone` | Ball | `void get_ball_zone()` |
| `launch_ball` | Ball | `void launch_ball(int p)` |
| `reset_shot` | Ball | `void reset_shot()` |
| `new_shot` | Ball | `void new_shot(int p)` |
| `reset_ball` | Ball | `void reset_ball()` |
| `respot_ball` | Ball | `void respot_ball()` |
| `shot_passed` | Ball | `void shot_passed()` |
| `stadium_bounds` | Ball | `void stadium_bounds()` |
| `pitch_bounds` | Ball | `void pitch_bounds()` |
| `rebound_post` | Ball | `void rebound_post()` |
| `rebound_bar` | Ball | `void rebound_bar()` |
| `own_goal` | Ball | `void own_goal()` |
| `good_goal` | Ball | `void good_goal()` |
| `hit_goal_post` | Ball | `void hit_goal_post()` |
| `hit_cross_bar` | Ball | `void hit_cross_bar()` |
| `hit_high_side_net` | Ball | `void hit_high_side_net()` |
| `hit_low_side_net` | Ball | `void hit_low_side_net()` |
| `hit_top_net` | Ball | `void hit_top_net()` |
| `hit_inside_back_net` | Ball | `void hit_inside_back_net()` |
| `hit_inside_back_net_r` | Ball | `void hit_inside_back_net_r()` |
| `hit_inside_top_net` | Ball | `void hit_inside_top_net()` |
| `hit_inside_high_side` | Ball | `void hit_inside_high_side()` |
| `hit_inside_low_side` | Ball | `void hit_inside_low_side()` |
| `real_player` | Ball | `short real_player(short p)` |
| `standard_player` | Ball | `short standard_player(short p)` |
| `country` | Ball | `short country(char t)` |
| `go_right_goal` | Ball | `void go_right_goal()` |
| `go_left_goal` | Ball | `void go_left_goal()` |
| `outside_of_net` | Ball | `void outside_of_net(float f,float y,float z)` |
| `is_it_a_goal` | Ball | `void is_it_a_goal()` |
| `ball_collision` | Ball | `void ball_collision()` |
| `oball_collision` | Ball | `void oball_collision()` |
| `get_ball_speed` | Ball | `void get_ball_speed()` |
| `ball_limbo` | Ball | `void ball_limbo(int p,float c)` |
| `ball_possession` | Ball | `void ball_possession()` |
| `process_ball` | Ball | `void process_ball()` |
| `out_mcball_coords` | BallInt | `void out_mcball_coords()` |
| `get_mcball_coords` | BallInt | `void get_mcball_coords(match_player *player)` |
| `user_header` | BallInt | `void user_header(match_player *player)` |
| `head_ball` | BallInt | `void head_ball(match_player *player)` |
| `ball_at_contact` | BallInt | `void ball_at_contact(match_player *player)` |
| `rebound_off_plr` | BallInt | `void rebound_off_plr(match_player *player)` |
| `has_ball` | BallInt | `void has_ball(match_player *player)` |
| `hold_ball` | BallInt | `void hold_ball(match_player *player)` |
| `init_specials` | BallInt | `void init_specials()` |
| `collect_ball` | BallInt | `void collect_ball(match_player *player)` |
| `active_control` | BallInt | `void active_control(match_player *player)` |
| `standard_fstep` | BallInt | `void standard_fstep(match_player *player)` |
| `control_interact` | BallInt | `char control_interact(match_player *player)` |
| `ball_interact` | BallInt | `void ball_interact(match_player *player)` |
| `predict_ball` | BallInt | `void predict_ball()` |
| `get_opp_near_ball` | BallInt | `void get_opp_near_ball(int holder)` |
| `get_dist_pos` | BallInt | `void get_dist_pos(int pn)` |
| `player_distances` | BallInt | `void player_distances()` |
| `get_nearest_guy` | BallInt | `int get_nearest_guy(int p_num)` |
| `get_nearest` | BallInt | `void get_nearest()` |
| `holder_lose_ball` | BallInt | `void holder_lose_ball()` |
| `full_spd` | Actions | `float full_spd(match_player *p)` |
| `actual_spd` | Actions | `float actual_spd(match_player *p)` |
| `init_officials` | Actions | `void init_officials()` |
| `check_practice` | Actions | `void check_practice()` |
| `init_team` | Actions | `void init_team()` |
| `taker_pass_f` | Actions | `void taker_pass_f(float xp,float yp)` |
| `taker_pass_h` | Actions | `void taker_pass_h(float xp,float yp)` |
| `taker_tee_up` | Actions | `void taker_tee_up(float x,float y)` |
| `taker_kick` | Actions | `void taker_kick(float x,float y)` |
| `taker_chip` | Actions | `void taker_chip(float x,float y)` |
| `taker_grnd` | Actions | `void taker_grnd(float x,float y)` |
| `rotate_lp` | Actions | `void rotate_lp(match_player *player)` |
| `rotate_around_ball` | Actions | `void rotate_around_ball(match_player *player)` |
| `taker_nkick` | Actions | `void taker_nkick()` |
| `draw_tracker` | Actions | `void draw_tracker(short mp,float x,float y)` |
| `init_runup_act` | Actions | `void init_runup_act(match_player *player)` |
| `user_runup` | Actions | `void user_runup(match_player *player)` |
| `new_user_spec_kick` | Actions | `void new_user_spec_kick(match_player *player)` |
| `user_pen_kick` | Actions | `void user_pen_kick(match_player *player,char user_guy)` |
| `user_spec_kick` | Actions | `void user_spec_kick(match_player *player)` |
| `user_limited_kick` | Actions | `void user_limited_kick(match_player *player)` |
| `comp_set_piece` | Actions | `void comp_set_piece(match_player *player)` |
| `user_set_piece` | Actions | `void user_set_piece(match_player *player)` |
| `init_throw_act` | Actions | `void init_throw_act(match_player *player)` |
| `init_get_up` | Actions | `void init_get_up(match_player *player,float fs)` |
| `init_pickup_act` | Actions | `void init_pickup_act(match_player *player)` |
| `pickup_action` | Actions | `void pickup_action(match_player *player)` |
| `init_taunt_act` | Actions | `void init_taunt_act(match_player *player)` |
| `init_run_celeb` | Actions | `void init_run_celeb(match_player *player,float tx,float ty)` |
| `init_stationary_celeb` | Actions | `void init_stationary_celeb(match_player *player)` |
| `init_celeb_act` | Actions | `void init_celeb_act(match_player *player)` |
| `celeb_action` | Actions | `void celeb_action(match_player *player)` |
| `init_stand_act` | Actions | `void init_stand_act(match_player *player)` |
| `init_steal_act` | Actions | `void init_steal_act(match_player *player)` |
| `init_kphold_act` | Actions | `void init_kphold_act(match_player *player)` |
| `angle_to_target` | Actions | `float angle_to_target(match_player *player)` |
| `angle_to_xy` | Actions | `float angle_to_xy(float a,float b,float x,float y)` |
| `init_stand_anims` | Actions | `void init_stand_anims(match_player *player)` |
| `init_trot_anims` | Actions | `void init_trot_anims(match_player *player)` |
| `init_run_anims` | Actions | `void init_run_anims(match_player *player)` |
| `init_run_act` | Actions | `void init_run_act(match_player *player,float tx,float ty,char s)` |
| `init_fall` | Actions | `void init_fall(match_player *player)` |
| `init_jump_act` | Actions | `void init_jump_act(match_player *player,char dir,char ride)` |
| `jump_action` | Actions | `void jump_action(match_player *player)` |
| `user_init_tackle` | Actions | `void user_init_tackle(match_player *player)` |
| `init_tackle_act` | Actions | `void init_tackle_act(match_player *player,float tx,float ty)` |
| `rotate_offs` | Actions | `void rotate_offs(int an,float &x,float &y,float &z,float nx,float ny)` |
| `init_save_act` | Actions | `void init_save_act(match_player *player,int tx,int ty,int tz,int an,int zone,int bp,int cont)` |
| `go_toward_target` | Actions | `void go_toward_target(match_player *player)` |
| `go_forward` | Actions | `void go_forward(match_player *player)` |
| `scorer_go` | Actions | `void scorer_go(match_player *player)` |
| `player_shame` | Actions | `void player_shame(match_player *player)` |
| `go_to_scorer` | Actions | `void go_to_scorer(match_player *player)` |
| `someone_has_scored` | Actions | `void someone_has_scored(match_player *player)` |
| `dont_run_off` | Actions | `void dont_run_off(match_player *player)` |
| `user_stand` | Actions | `void user_stand(match_player *player)` |
| `kick_strike` | Actions | `void kick_strike(match_player *player)` |
| `overhead_strike` | Actions | `void overhead_strike(match_player *player)` |
| `chip_strike` | Actions | `void chip_strike(match_player *player)` |
| `head_strike` | Actions | `void head_strike(match_player *player)` |
| `dvhead_strike` | Actions | `void dvhead_strike(match_player *player)` |
| `strike_ball_off` | Actions | `void strike_ball_off(match_player *player)` |
| `fire_ball_off` | Actions | `void fire_ball_off()` |
| `init_kick_act` | Actions | `void init_kick_act(match_player *player,int mc,float pc)` |
| `kick_action` | Actions | `void kick_action(match_player *player)` |
| `steal_action` | Actions | `void steal_action(match_player *player)` |
| `stand_action` | Actions | `void stand_action(match_player *player)` |
| `user_throw` | Actions | `void user_throw(match_player *player)` |
| `throw_action` | Actions | `void throw_action(match_player *player)` |
| `user_run` | Actions | `void user_run(match_player *player)` |
| `kphold_action` | Actions | `void kphold_action(match_player *player)` |
| `wait_action` | Actions | `void wait_action(match_player *player)` |
| `stop_action` | Actions | `void stop_action(match_player *player)` |
| `init_stop_act` | Actions | `void init_stop_act(match_player *player,float x,float y)` |
| `init_wait_act` | Actions | `void init_wait_act(match_player *player,float x,float y)` |
| `control_action` | Actions | `void control_action(match_player *player)` |
| `get_closest_pred` | Actions | `void get_closest_pred(match_player *player,float &rt,float &x,float &y,float &z,float &d)` |
| `init_control_act` | Actions | `void init_control_act(match_player *player)` |
| `strike_action` | Actions | `void strike_action(match_player *player)` |
| `init_first_time_act` | Actions | `void init_first_time_act(match_player *player,int mc,float pc)` |
| `oinit_first_time_act` | Actions | `void oinit_first_time_act(match_player *player,int mc,float pc)` |
| `init_strike_act` | Actions | `void init_strike_act(match_player *player)` |
| `orun_action` | Actions | `void orun_action(match_player *player)` |
| `run_action` | Actions | `void run_action(match_player *player)` |
| `tackle_action` | Actions | `void tackle_action(match_player *player)` |
| `save_action` | Actions | `void save_action(match_player *player)` |
| `fall_action` | Actions | `void fall_action(match_player *player)` |
| `init_tussles` | Actions | `void init_tussles()` |
| `tussle_collision` | Actions | `void tussle_collision(match_player *p1,match_player *p2)` |
| `player_tussles` | Actions | `void player_tussles()` |
| `add_to_tussle_list` | Actions | `void inline add_to_tussle_list(int pnum)` |
| `do_action` | Actions | `void do_action()` |
| `new_dir` | Actions | `void new_dir(match_player *player,float x,float y)` |
| `dir_movement` | Actions | `void dir_movement(match_player *player)` |
| `dir_ball` | Actions | `void dir_ball(match_player *player)` |
| `dir_new_d` | Actions | `void dir_new_d(match_player *player)` |
| `dir_must_face` | Actions | `void dir_must_face(match_player *player)` |
| `dir_away` | Actions | `void dir_away(match_player *player)` |
| `select_hlite` | Actions | `void select_hlite(match_player *player,short u)` |
| `user_conts` | Actions | `void user_conts(match_player *player)` |
| `process_dir` | Actions | `void process_dir(match_player *player)` |
| `init_stand_anim` | Actions | `void init_stand_anim(match_player *player)` |
| `init_penalty_anim` | Actions | `void init_penalty_anim(match_player *player)` |
| `init_shame_anim` | Actions | `void init_shame_anim(match_player *player)` |
| `init_standb_anim` | Actions | `void init_standb_anim(match_player *player)` |
| `init_barge_anim` | Actions | `void init_barge_anim(match_player *player)` |
| `init_run_anim` | Actions | `void init_run_anim(match_player *player)` |
| `init_jog_anim` | Actions | `void init_jog_anim(match_player *player)` |
| `init_shoot_anim` | Actions | `void init_shoot_anim(match_player *player)` |
| `init_kick_anim` | Actions | `void init_kick_anim(match_player *player,int a)` |
| `init_kick_l_anim` | Actions | `void init_kick_l_anim(match_player *player,int a)` |
| `init_kick_r_anim` | Actions | `void init_kick_r_anim(match_player *player,int a)` |
| `init_trap_anim` | Actions | `void init_trap_anim(match_player *player)` |
| `init_ride_anim` | Actions | `void init_ride_anim(match_player *player)` |
| `init_tack_anim` | Actions | `void init_tack_anim(match_player *player)` |
| `init_shdr_anim` | Actions | `void init_shdr_anim(match_player *player)` |
| `init_jhdr_anim` | Actions | `void init_jhdr_anim(match_player *player)` |
| `init_dhdr_anim` | Actions | `void init_dhdr_anim(match_player *player)` |
| `init_ohd_anim` | Actions | `void init_ohd_anim(match_player *player)` |
| `init_voll_anim` | Actions | `void init_voll_anim(match_player *player)` |
| `init_fallr_anim` | Actions | `void init_fallr_anim(match_player *player)` |
| `init_chest_anim` | Actions | `void init_chest_anim(match_player *player)` |
| `init_dnhead_anim` | Actions | `void init_dnhead_anim(match_player *player)` |
| `init_getupf_anim` | Actions | `void init_getupf_anim(match_player *player)` |
| `init_getup_anim` | Actions | `void init_getup_anim(match_player *player)` |
| `init_save_anim` | Actions | `void init_save_anim(match_player *player,int an)` |
| `init_bounce_anim` | Actions | `void init_bounce_anim(match_player *player)` |
| `init_kout_anim` | Actions | `void init_kout_anim(match_player *player)` |
| `init_hvoll_anim` | Actions | `void init_hvoll_anim(match_player *player)` |
| `init_throw_anim` | Actions | `void init_throw_anim(match_player *player)` |
| `init_roll_anim` | Actions | `void init_roll_anim(match_player *player)` |
| `init_runb_anim` | Actions | `void init_runb_anim(match_player *player)` |
| `init_waveup_anim` | Actions | `void init_waveup_anim(match_player *player)` |
| `init_throwl_anim` | Actions | `void init_throwl_anim(match_player *player)` |
| `init_throws_anim` | Actions | `void init_throws_anim(match_player *player)` |
| `init_crtostb_anim` | Actions | `void init_crtostb_anim(match_player *player)` |
| `init_crl_anim` | Actions | `void init_crl_anim(match_player *player)` |
| `init_crr_anim` | Actions | `void init_crr_anim(match_player *player)` |
| `init_tostand_anim` | Actions | `void init_tostand_anim(match_player *player,int an)` |
| `init_tostandb_anim` | Actions | `void init_tostandb_anim(match_player *player,int an)` |
| `init_socks_anim` | Actions | `void init_socks_anim(match_player *player,int an)` |
| `init_celeb_anim` | Actions | `void init_celeb_anim(match_player *player,int an)` |
| `init_pickup_anim` | Actions | `void init_pickup_anim(match_player *player)` |
| `init_trot_anim` | Actions | `void init_trot_anim(match_player *player)` |
| `init_anim` | Actions | `void init_anim(match_player *player,int an)` |
| `process_anims` | Actions | `void process_anims(match_player *player)` |
| `user_play` | Actions | `void user_play(int player_num)` |
| `computer_play` | Actions | `void computer_play(int player_num)` |
| `go_team` | Actions | `void go_team(int p)` |
| `select_all_hlites` | Actions | `void select_all_hlites()` |
| `process_teams` | Actions | `void process_teams()` |
| `get_there_time` | Intell | `short get_there_time(int p_num,float x,float y)` |
| `get_facing_opp_dir` | Intell | `short get_facing_opp_dir(match_player *player)` |
| `thinking` | Intell | `char thinking(match_player *player)` |
| `plr_facing` | Intell | `char plr_facing(float x,float y,match_player *player)` |
| `plr_facing_goal` | Intell | `char plr_facing_goal(float x,float y,match_player *player)` |
| `run_back` | Intell | `void run_back(match_player *player)` |
| `keeper_boxes` | Intell | `void keeper_boxes()` |
| `reset_ideas` | Intell | `void reset_ideas(match_player *player)` |
| `reset_all_ideas` | Intell | `void reset_all_ideas()` |
| `reset_leaves` | Intell | `void reset_leaves()` |
| `save_in_zone_a` | Intell | `void save_in_zone_a(match_player *player,float x,float y,float z,int bp,char forced)` |
| `save_in_zone_b` | Intell | `void save_in_zone_b(match_player *player,float x,float y,float z,int bp,char forced)` |
| `save_in_zone_c` | Intell | `void save_in_zone_c(match_player *player,float x,float y,float z,int bp,char forced)` |
| `close_angle` | Intell | `void close_angle(match_player *player,float d,float &x,float &y)` |
| `target_towards_ball` | Intell | `char target_towards_ball(float tx,float ty,float px,float py)` |
| `init_user_save` | Intell | `void init_user_save(match_player *player)` |
| `go_to_save_path` | Intell | `void go_to_save_path(match_player *player,char forced=FALSE)` |
| `fake_ball_poss` | Intell | `void fake_ball_poss(int p,float x,float y,float z)` |
| `restore_ball_poss` | Intell | `void restore_ball_poss()` |
| `kick_straight` | Intell | `char kick_straight()` |
| `first_time_strike` | Intell | `char first_time_strike(int p,float x,float y,float z,float px,float py)` |
| `user_pass_check` | Intell | `char user_pass_check(int p,float x,float y,float z,float px,float py)` |
| `decide_strike` | Intell | `void decide_strike(match_player *p,short t,char c,char s)` |
| `strike_and_control` | Intell | `void strike_and_control(match_player *player,intercept_data *s,short action)` |
| `cancel_int` | Intell | `void cancel_int(int p)` |
| `intercept` | Intell | `void intercept(int p)` |
| `fstep_factor` | Intell | `float fstep_factor(short c)` |
| `can_i_intercept` | Intell | `char can_i_intercept(int p_num,float x,float y,float z,float px,float py,short i)` |
| `can_i_intercept` | Intell | `char can_i_intercept(int p_num,float x,float y,float z,float px,float py,short i) **(duplicate definition; also in Intell)**` |
| `clear_strike` | Intell | `void clear_strike()` |
| `decide_on_face` | Intell | `void decide_on_face(match_player *p)` |
| `set_there_flags` | Intell | `void set_there_flags(short taker)` |
| `centre_pos` | Intell | `void centre_pos(char flag,int pn,char &flag2,float &x,float &y)` |
| `gkick_pos` | Intell | `void gkick_pos(char flag,int pn,char &flag2,float &x,float &y,char &taker)` |
| `corner_pos` | Intell | `void corner_pos(char flag,int pn,char &flag2,float &x,float &y,char &taker)` |
| `throw_in_pos` | Intell | `void throw_in_pos(char flag,int pn,char &flag2,float &x,float &y,char &taker)` |
| `dfkick_pos` | Intell | `void dfkick_pos(char flag,int pn,char &flag2,float &x,float &y,char &taker)` |
| `fkick_pos` | Intell | `void fkick_pos(char flag,int pn,char &flag2,float &x,float &y,char &taker)` |
| `penalty_pos` | Intell | `void penalty_pos(char flag,int pn,char &flag2,float &x,float &y,char &taker)` |
| `tunnel_pos` | Intell | `void tunnel_pos(char flag,int pn,float &x,float &y)` |
| `get_tac` | Intell | `int get_tac(int *t)` |
| `find_zonal_target` | Intell | `void find_zonal_target(match_player *player,float px,float py)` |
| `get_near_path` | Intell | `int get_near_path(int p_num,int not_busy)` |
| `oget_near_path` | Intell | `int oget_near_path(int p_num,int not_busy)` |
| `forward_joystick` | Intell | `void forward_joystick(match_player *p,float &x,float &y)` |
| `get_face_xy` | Intell | `void get_face_xy(int d,float &x,float &y)` |
| `get_dir` | Intell | `int get_dir(float x,float y)` |
| `angle_of_vis` | Intell | `int angle_of_vis(match_player *player,int x,int y,float d,char cross=FALSE)` |
| `get_opp_dir_tab` | Intell | `void get_opp_dir_tab(int pnum)` |
| `opp_around` | Intell | `int opp_around(int x,int y,int pnum)` |
| `kopp_around` | Intell | `int kopp_around(int x,int y,int pnum)` |
| `facing_opp` | Intell | `float facing_opp(match_player *player,short opp)` |
| `player_ints` | Intell | `void player_ints(match_player *player)` |
| `cross_angle` | Intell | `char cross_angle(float xd,float yd,float x,float y)` |
| `new_interceptor` | Intell | `void new_interceptor(int p)` |
| `pass_ahead` | Intell | `int pass_ahead(int ps,float &x,float &y,float &pass_speed,float &end_speed,char cross)` |
| `choose_pass` | Intell | `void choose_pass(int ps,float &x,float &y,float &pass_speed,float &end_speed,char cross)` |
| `pass_ball` | Intell | `void pass_ball(int ps,char cross)` |
| `make_pass` | Intell | `void make_pass(match_player *player,int p,char cross=FALSE)` |
| `dribble_dir` | Intell | `void dribble_dir(match_player *player,float &xd,float &yd)` |
| `avoid_boundary` | Intell | `void avoid_boundary(match_player *player)` |
| `go_dribble` | Intell | `void go_dribble(match_player *player,float x,float y)` |
| `make_run` | Intell | `void make_run(match_player *player)` |
| `run_decide` | Intell | `int run_decide(match_player *player)` |
| `make_punt` | Intell | `void make_punt(match_player *player)` |
| `punt_ball` | Intell | `void punt_ball(match_player *player)` |
| `punt_decide` | Intell | `int punt_decide(match_player *player)` |
| `head_punt_decide` | Intell | `int head_punt_decide(match_player *player)` |
| `get_power` | Intell | `float get_power()` |
| `get_traj` | Intell | `float get_traj()` |
| `aim_shot_at_goal` | Intell | `void aim_shot_at_goal(match_player *player,float &xoff,float &yoff,int rng)` |
| `make_shoot` | Intell | `void make_shoot(match_player *player)` |
| `shoot_ball` | Intell | `void shoot_ball(match_player *player)` |
| `shoot_decide` | Intell | `int shoot_decide(match_player *player)` |
| `head_shoot_decide` | Intell | `int head_shoot_decide(match_player *player)` |
| `sort_less_than` | Intell | `int sort_less_than(const void *op1, const void *op2)` |
| `sort_greater_than` | Intell | `int sort_greater_than(const void *op1, const void *op2)` |
| `sort_soonest` | Intell | `int sort_soonest(const void *op1, const void *op2)` |
| `kicking_dist` | Intell | `float kicking_dist(match_player *player,float x,float y,float d)` |
| `in_kicking_range` | Intell | `int in_kicking_range(match_player *player,float x,float y)` |
| `can_i_pass` | Intell | `int can_i_pass(match_player *player)` |
| `pass_decide` | Intell | `int pass_decide(match_player *player,char cross=FALSE)` |
| `process_comments` | Intell | `void process_comments()` |
| `init_speech` | Intell | `void init_speech(int p,int comm,int t)` |
| `process_speech` | Intell | `void process_speech()` |
| `player_comment` | Intell | `void player_comment(match_player *player)` |
| `tackle_decide` | Intell | `void tackle_decide(match_player *player)` |
| `steal_decide` | Intell | `void steal_decide(match_player *player)` |
| `block_decide` | Intell | `void block_decide(match_player *player)` |
| `user_free_ball` | Intell | `void user_free_ball(match_player *player)` |
| `other_interceptor` | Intell | `void other_interceptor(match_player *player)` |
| `free_ball` | Intell | `void free_ball(match_player *player)` |
| `out_of_vis` | Intell | `void out_of_vis(match_player *player)` |
| `range_flags` | Intell | `void range_flags(match_player *player)` |
| `cross_pos` | Intell | `void cross_pos(match_player *player)` |
| `set_pos_flags` | Intell | `void set_pos_flags(match_player *player)` |
| `user_got_ball` | Intell | `void user_got_ball(match_player *player)` |
| `got_ball` | Intell | `void got_ball(match_player *player)` |
| `help_chance` | Intell | `int help_chance(match_player *player)` |
| `we_have_ball` | Intell | `void we_have_ball(match_player *player)` |
| `in_close` | Intell | `int in_close(match_player *player)` |
| `can_close_down` | Intell | `int can_close_down(match_player *player)` |
| `close_him_down` | Intell | `void close_him_down(match_player *player)` |
| `force_error` | Intell | `void force_error(match_player *player)` |
| `forceful_retrieve` | Intell | `void forceful_retrieve(match_player *player)` |
| `user_opp_has_ball` | Intell | `void user_opp_has_ball(match_player *player)` |
| `opp_has_ball` | Intell | `void opp_has_ball(match_player *player)` |
| `user_intelligence` | Intell | `void user_intelligence(match_player *player)` |
| `offside_rule` | Intell | `void offside_rule(match_player *player)` |
| `override` | Intell | `void override(match_player *player)` |
| `remove_player` | Intell | `void remove_player(match_player *player)` |
| `init_off_int` | Intell | `void init_off_int(match_player *player)` |
| `intelligence` | Intell | `void intelligence(match_player *player)` |
| `decide_set_kick` | Rules | `void decide_set_kick()` |
| `all_standing` | Rules | `char all_standing()` |
| `clear_wall` | Rules | `void clear_wall()` |
| `ready_set_kick` | Rules | `void ready_set_kick()` |
| `go_set_kick` | Rules | `void go_set_kick(char type)` |
| `ready_ckick` | Rules | `void ready_ckick()` |
| `go_ckick` | Rules | `void go_ckick(char type)` |
| `await_set_kick` | Rules | `void await_set_kick()` |
| `swap_users` | Rules | `void swap_users()` |
| `swap_teams` | Rules | `void swap_teams()` |
| `in_tunnel` | Rules | `char in_tunnel()` |
| `await_swap` | Rules | `void await_swap()` |
| `remember_cam` | Rules | `void remember_cam()` |
| `init_swap_ends` | Rules | `void init_swap_ends()` |
| `await_throw` | Rules | `void await_throw()` |
| `ball_situation` | Rules | `void ball_situation()` |
| `stop` | Rules | `void stop()` |
| `add_player_time` | Rules | `void add_player_time()` |
| `match_clock` | Rules | `void match_clock()` |
| `kill_ball` | Rules | `void kill_ball()` |
| `pen_to_team_a` | Rules | `void pen_to_team_a()` |
| `pen_to_team_b` | Rules | `void pen_to_team_b()` |
| `do_penalties` | Rules | `void do_penalties()` |
| `match_rules` | Rules | `void match_rules()` |
| `bounds_rules` | Rules | `char bounds_rules()` |
| `throw_taker` | Rules | `void throw_taker(int p)` |
| `get_taker` | Rules | `int get_taker(int p)` |
| `centre_takers` | Rules | `void centre_takers()` |
| `init_centre` | Rules | `void init_centre()` |
| `init_corner` | Rules | `void init_corner()` |
| `init_gkick` | Rules | `void init_gkick()` |
| `init_throw` | Rules | `void init_throw()` |
| `penalty` | Rules | `char penalty(int fouler)` |
| `init_offside` | Rules | `void init_offside(match_player *player)` |
| `big_yeller` | Rules | `void big_yeller(int plr)` |
| `ger_em_off` | Rules | `void ger_em_off(int plr)` |
| `send_off_plr` | Rules | `void send_off_plr(int plr,float nasty)` |
| `punish_foul` | Rules | `void punish_foul(int fouler,char direct)` |
| `retake_foul` | Rules | `void retake_foul()` |
| `init_foul` | Rules | `void init_foul(int fouler,char direct,char see)` |
| `force_penalty` | Rules | `void force_penalty()` |
| `init_fkick` | Rules | `void init_fkick()` |
| `find_wall_guys` | Rules | `void find_wall_guys(int guys,float x,float y)` |
| `inc_pfoul` | Rules | `void inc_pfoul(short p)` |
| `inc_dfoul` | Rules | `void inc_dfoul(short p)` |
| `inc_ifoul` | Rules | `void inc_ifoul(short p)` |
| `inc_pass` | Rules | `void inc_pass(short p)` |
| `inc_work` | Rules | `void inc_work(short p)` |
| `inc_pwon` | Rules | `void inc_pwon(short p)` |
| `inc_tack` | Rules | `void inc_tack(short p)` |
| `inc_twon` | Rules | `void inc_twon(short p)` |
| `inc_poss` | Rules | `void inc_poss(short p)` |
| `inc_inj` | Rules | `void inc_inj(short p,short i)` |
| `inc_yellow` | Rules | `void inc_yellow(short p)` |
| `inc_red` | Rules | `void inc_red(short p)` |
| `inc_shot` | Rules | `void inc_shot(short p)` |
| `inc_goal` | Rules | `void inc_goal(short p)` |
| `inc_ogs` | Rules | `void inc_ogs(short p)` |
| `inc_save` | Rules | `void inc_save(short p)` |
| `inc_saves` | Rules | `void inc_saves(short p)` |
| `add_comp_pass` | Rules | `void add_comp_pass(short plr)` |
| `init_dfkick` | Rules | `void init_dfkick()` |
| `init_penalty` | Rules | `void init_penalty()` |
| `init_match_mode` | Rules | `void init_match_mode()` |
| `offc_thinking` | Rules | `char offc_thinking()` |
| `init_ref_stand` | Rules | `void init_ref_stand(officials *lman)` |
| `init_ref_run` | Rules | `void init_ref_run(officials *lman)` |
| `init_ref_jog` | Rules | `void init_ref_jog(officials *lman)` |
| `init_rtrot_anim` | Rules | `void init_rtrot_anim(officials *lman)` |
| `init_refs_anim` | Rules | `void init_refs_anim(officials *lman,int an)` |
| `lman_follow` | Rules | `void lman_follow(officials *lman)` |
| `await_kicker` | Rules | `void await_kicker(officials *offc)` |
| `goto_target` | Rules | `void goto_target(officials *offc)` |
| `at_target` | Rules | `void at_target(officials *referee)` |
| `follow_play` | Rules | `void follow_play(officials *referee)` |
| `process_ref` | Rules | `void process_ref(officials *offc)` |
| `process_lman` | Rules | `void process_lman(officials *offc)` |
| `anim_officials` | Rules | `void anim_officials(officials *offc)` |
| `process_offs` | Rules | `void process_offs()` |
| `init_keyboard` | User | `void init_keyboard()` |
| `delete_net_user` | User | `void delete_net_user(int u)` |
| `add_team_user` | User | `void add_team_user(short t,short c)` |
| `add_fixed_user` | User | `void add_fixed_user(short p,short c)` |
| `clear_all_fixed` | User | `void clear_all_fixed()` |
| `init_users` | User | `void init_users()` |
| `go_button` | User | `void go_button()` |
| `mouse_fired` | User | `void mouse_fired()` |
| `process_butts` | User | `void process_butts()` |
| `convert_inputs` | User | `void convert_inputs()` |
| `clear_auto` | User | `void clear_auto(short u)` |
| `clear_all_autos` | User | `void clear_all_autos()` |
| `reset_f_held` | User | `void reset_f_held()` |
| `user_keeper_a` | User | `short user_keeper_a()` |
| `user_keeper_b` | User | `short user_keeper_b()` |
| `user_taker_a` | User | `short user_taker_a(short p)` |
| `user_taker_b` | User | `short user_taker_b(short p)` |
| `auto_select_a` | User | `void auto_select_a(short u)` |
| `auto_select_b` | User | `void auto_select_b(short u)` |
| `reselect_a` | User | `void reselect_a()` |
| `reselect_b` | User | `void reselect_b()` |
| `reselect` | User | `void reselect()` |
| `reselect_all_users` | User | `void reselect_all_users()` |
| `force_users` | User | `void force_users()` |
| `new_users` | User | `void new_users()` |
| `checksum` | Football | `void checksum()` |
| `make_mtable` | Football | `void make_mtable(int t1,int t2)` |
| `player_stamina` | Football | `void player_stamina()` |
| `process_flags` | Football | `void process_flags()` |
| `init_line_up` | Football | `void init_line_up()` |
| `convert_control` | Football | `short convert_control(char c)` |
| `conv_conts_back` | Football | `short conv_conts_back(char c)` |
| `init_rand` | Football | `void init_rand()` |
| `get_performance` | Football | `void get_performance()` |
| `initialise_vars` | Football | `void initialise_vars()` |
| `init_user_controls` | Football | `void init_user_controls()` |
| `svgacpy2` | Football | `void svgacpy2(unsigned char *buffpt,short x,short y,short w,short h)` |
| `display_endscr` | Football | `void display_endscr()` |
| `display_screen` | Football | `void display_screen()` |
| `load_new_tactics` | Football | `void load_new_tactics()` |
| `init_match` | Football | `void init_match()` |
| `init_player_stats` | Football | `void init_player_stats(short p)` |
| `process_subs` | Football | `void process_subs()` |
| `save_state` | Football | `void save_state(save_data *save_it)` |
| `restore_state` | Football | `void restore_state(save_data *save_it)` |
| `checksum_state` | Football | `void checksum_state()` |
| `process_state` | Football | `void process_state()` |
| `reset_state` | Football | `void reset_state(char buff)` |
| `variable_wind` | Football | `void variable_wind()` |
| `do_logic` | Football | `void do_logic()` |
| `stop_mf_time` | Football | `void stop_mf_time()` |
| `pause_game` | Football | `void pause_game()` |
| `init_joy1` | Football | `void init_joy1()` |
| `init_joy2` | Football | `void init_joy2()` |
| `init_joys` | Football | `void init_joys()` |
| `process_keys` | Football | `void process_keys()` |
| `animate_players` | Football | `void animate_players()` |
| `update_2d` | Football | `void update_2d()` |
| `reset_possession` | Football | `void reset_possession()` |
| `accumulate_possession` | Football | `void accumulate_possession()` |
| `process_crowd_noise` | Football | `void process_crowd_noise()` |
| `nothing_happening` | Football | `char nothing_happening()` |
| `watch_match_time` | Football | `void watch_match_time()` |
| `setup_alarm` | Football | `void setup_alarm()` |
| `init_wind` | Football | `void init_wind()` |
| `NetUserInit` | Football | `void NetUserInit()` |
| `TimerInit` | Football | `void TimerInit()` |
| `reset_front` | Football | `void reset_front()` |
| `match` | Football | `int match(int argc, char **argv)` |
| `init_3d` | Upd3D | `int init_3d()` |
| `setup_replay` | Upd3D | `void setup_replay()` |
| `reset_replay` | Upd3D | `void reset_replay()` |
| `sub_player` | Upd3D | `void sub_player(short t,short p,short s)` |
| `do_replay_render3d` | Upd3D | `void do_replay_render3d(float s)` |
| `process_replay` | Upd3D | `void process_replay()` |
| `plr_comments` | Upd3D | `void plr_comments()` |
| `process_pitch_sprs` | Upd3D | `void process_pitch_sprs()` |
| `init_replay` | Upd3D | `void init_replay()` |
| `draw_string_center` | Upd3D | `void draw_string_center(int x,int y,char *st,buff_info *buff)` |
| `draw_string_left` | Upd3D | `void draw_string_left(int x,int y,char *st,buff_info *buff)` |
| `draw_string_right` | Upd3D | `void draw_string_right(int x,int y,char *st,buff_info *buff)` |
| `set_normal_color` | Upd3D | `void set_normal_color(int c)` |
| `extra_info` | Upd3D | `void extra_info()` |
| `info_line` | Upd3D | `void info_line()` |
| `damping_off` | Upd3D | `void damping_off()` |
| `add_message` | Upd3D | `void add_message(char *t,short c,char force)` |
| `display_messages` | Upd3D | `void display_messages()` |
| `change_cam` | Upd3D | `void change_cam(short c)` |
| `update_3d` | Upd3D | `void update_3d()` |
| `pass_coords` | Upd3D | `void pass_coords(plyrdat *ptr)` |
| `switch_coords` | Upd3D | `void switch_coords()` |
| `new_update_coords` | Upd3D | `void new_update_coords()` |
| `realtime_coords` | Upd3D | `void realtime_coords()` |
| `sprite3d` | Upd3D | `void sprite3d(short x,short y,short ref)` |
| `read_joy1` | NetInput | `void read_joy1(unsigned short *x, unsigned short *y, unsigned char *sw)` |
| `read_joy2` | NetInput | `void read_joy2(unsigned short *x, unsigned short *y, unsigned char *sw)` |
| `read_joystick` | NetInput | `void read_joystick(char j, unsigned short *x, unsigned short *y, unsigned char *sw)` |
| `get_joy_max_min` | NetInput | `void get_joy_max_min(char j)` |
| `calibrate_joy` | NetInput | `void calibrate_joy(char j,unsigned short *x,unsigned short *y)` |
| `sqrt_i` | NetInput | `int sqrt_i(int a)` |
| `normalise_joy_i` | NetInput | `void normalise_joy_i(volatile int *x,volatile int *y)` |
| `calc_dist_i` | NetInput | `int calc_dist_i(int x,int y)` |
| `get_joy_dir1` | NetInput | `void get_joy_dir1(volatile int *x,volatile int *y,volatile int *f)` |
| `get_joy_dir2` | NetInput | `void get_joy_dir2(volatile int *x,volatile int *y,volatile int *f)` |
| `get_mouse_dir` | NetInput | `void get_mouse_dir(volatile struct user_config *user)` |
| `get_key_code` | NetInput | `short get_key_code(signed char *ks)` |
| `get_key_dir` | NetInput | `void get_key_dir(volatile struct user_config *user,signed char *kb)` |
| `get_user_inputs` | NetInput | `void get_user_inputs()` |
| `process_user_inputs` | NetInput | `void process_user_inputs()` |
| `nethandler` | NetInput | `void __far nethandler(void)` |
| `TickPause` | NetInput | `void TickPause()` |
| `FindAddress` | NetInput | `int FindAddress(_NETNOW_NODE_ADDR daddress)` |
| `pausehandler` | NetInput | `void pausehandler()` |
| `Initialise_Network` | NetInput | `int Initialise_Network()` |
| `Poll_Network` | NetInput | `int Poll_Network()` |
| `Start_Network_Game` | NetInput | `int Start_Network_Game()` |
| `Network_Play_Ready` | NetInput | `void Network_Play_Ready()` |
| `Quit_Network_Play` | NetInput | `void Quit_Network_Play()` |
| `End_Network_Game` | NetInput | `void End_Network_Game()` |
| `NetTest` | NetInput | `int NetTest()` |
| `crap` | NetInput | `void crap()` |
| `init_pitch_sprites` | Display | `void init_pitch_sprites()` |
| `add_pitch_sprite` | Display | `void add_pitch_sprite(short x,short y,short z,short ref)` |
| `grid_map` | Display | `void grid_map()` |
| `line_border` | Display | `void line_border(int x,int y,int wid,int hgt,int col)` |
| `draw_buttons` | Display | `void draw_buttons()` |
| `light_button` | Display | `void light_button(int b)` |
| `unlight_button` | Display | `void unlight_button(int b)` |
| `conv_xypitch` | Display | `void conv_xypitch(float x, float y, int *screen_x, int *screen_y)` |
| `pitch_markings` | Display | `void pitch_markings()` |
| `draw_pitch` | Display | `void draw_pitch()` |
| `draw_buffer` | Display | `void draw_buffer()` |
| `draw_ball` | Display | `void draw_ball()` |
| `draw_team` | Display | `void draw_team()` |
| `panel_data` | Display | `void panel_data()` |
| `slower` | Display | `void slower()` |
| `faster` | Display | `void faster()` |
| `show_nums` | Display | `void show_nums()` |
| `frame_count` | Display | `void frame_count()` |
| `oframe_count` | Display | `void oframe_count()` |
