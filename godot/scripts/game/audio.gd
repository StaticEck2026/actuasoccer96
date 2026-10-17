# Audio interface of the match engine (AUDIO.H / MY_AUDIO.CPP).
# The original sample banks (crowd, commentary, pitch fx) are not part of the
# source release, so these calls are routed to an optional sound layer through
# the `audio_event` hook; with no layer attached they are silent.
class_name Audio extends Glob

# Optional sink: Callable(event_name: String, args: Array)
static var sink: Callable = Callable()

static func _emit(ev: String, args: Array = []) -> void:
	if sink.is_valid():
		sink.call(ev, args)

# void play_fx(int fx,float x,float y)   (MY_AUDIO.CPP)
static func play_fx(fx: int, x: float, y: float) -> void:
	var pan: int
	var vol: int
	var d: float
	var xd: float
	var yd: float
	var zd: float
	xd = x - Upd3D.camera_x
	yd = y - Upd3D.camera_x		# (sic) original uses camera_x here
	zd = Upd3D.camera_z

	d = Maths.calc_dist(x - Upd3D.camera_x, y - Upd3D.camera_y)
	d = Maths.calc_dist(d, zd)
	xd = xd / d
	yd = yd / d

	if d < MAX_VOL_DIST:
		vol = 0x7fff
	else:
		vol = int((MAX_VOL_DIST / d) * 0x7fff)

	d = ((xd * cth) + (yd * sth))
	pan = int(0x8000 + (d * 0x8000))

	if EUROmatch_info.audio == 2:
		# 3D Sound...
		PlayPitchSample(fx, vol, pan)
	else:
		# Mono...
		PlayPitchSample(fx, 0x7fff, 0x8000)

static func InitMatchAudio(seed_v: int) -> int: _emit("InitMatchAudio", [seed_v]); return 0
static func UpdateVolumeLevels() -> void: _emit("UpdateVolumeLevels")
static func LoadPitchSamples() -> int: return 0
static func FreePitchSamples() -> void: pass
static func PlayPitchSample(sam: int, amp: int, pan: int) -> int: _emit("PlayPitchSample", [sam, amp, pan]); return 0
static func StartCrowd(team: int) -> void: _emit("StartCrowd", [team])
static func StopAudio() -> void: _emit("StopAudio")
static func PlayCrowdSample(sam: int) -> int: _emit("PlayCrowdSample", [sam]); return 0
static func UpdateCrowd(mood: int, team: int) -> void: _emit("UpdateCrowd", [mood, team])
static func LoadTeamSamples(team_num: int, team: int) -> int: return 0
static func FreeTeamSamples(team: int) -> void: pass
static func LoadCommentarySamples() -> int: return 0
static func FreeCommentarySamples() -> void: pass
static func UpdateCommentary() -> void: pass
static func PauseCommentary() -> void: _emit("PauseCommentary")
static func ResumeCommentary() -> void: _emit("ResumeCommentary")
static func PlayTeamSample(player: int, intonation: int) -> int: _emit("PlayTeamSample", [player, intonation]); return 0
static func PlayWelcomeMessage() -> void: _emit("PlayWelcomeMessage")
static func PlaySubstitutionMessage(team: int, player_off: int, player_on: int, injured: int) -> void: _emit("PlaySubstitutionMessage", [team, player_off, player_on, injured])
static func PlayScoreSample(home: int, away: int) -> void: _emit("PlayScoreSample", [home, away])
static func PlayCommentaryMessage(type: int) -> void: _emit("PlayCommentaryMessage", [type])
static func PlayPossessionSample(team: int) -> void: _emit("PlayPossessionSample", [team])
static func CheckCommentary() -> int: return 0
