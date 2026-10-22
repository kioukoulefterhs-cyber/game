extends RefCounted
## Garden economy over the real campaign: players of every skill keep earning rewards.
## Simulates 1-, 2- and 3-star players who buy the cheapest garden item as soon as they can.

const PACK := "res://puzzles/levels_v1.json"
var t


func _simulate(stars: int) -> Dictionary:
	var levels := CGLevel.load_pack(PACK)
	var costs: Array = []
	for item in CGGarden.PLANTS + CGGarden.DECOR:
		costs.append(int(item.cost))
	costs.sort()
	var seeds := 0
	var last_buy := 0
	var reward_levels: Array[int] = []
	for i in levels.size():
		var n := i + 1
		var lv: CGLevel = levels[i]
		seeds += int(CGGame.SEEDS_FIRST_CLEAR_BY_LABEL.get(lv.difficulty.label, CGGame.SEEDS_FIRST_CLEAR))
		seeds += CGGame.SEEDS_PER_STAR * stars
		var rewarded := false
		for m in CGGarden.milestones_between(n - 1, n):
			seeds += int(m.seeds)
			rewarded = true
		for th in CGGarden.THEMES:
			rewarded = rewarded or int(th.levels) == n
		while not costs.is_empty() and seeds >= int(costs[0]):
			seeds -= int(costs.pop_front())
			rewarded = true
			last_buy = n
		if rewarded:
			reward_levels.append(n)
	var gap := 0
	var prev := 0
	for n in reward_levels:
		gap = maxi(gap, n - prev)
		prev = n
	return {"left": costs.size(), "gap": maxi(gap, levels.size() - prev), "seeds": seeds,
		"last": reward_levels.back(), "last_buy": last_buy}


func test_every_player_keeps_earning_rewards() -> void:
	for stars in [1, 2, 3]:
		var r := _simulate(stars)
		t.check(r.gap <= 10, "%d-star player waits at most 10 levels for a reward (was %d)" % [stars, r.gap])
		# 1-star players may need a few daily puzzles (not simulated) for the last item.
		t.check(r.left <= (1 if stars == 1 else 0), "%d-star player owns the garden by level 100 (%d items left)" % [stars, r.left])
		t.eq(r.last, 100, "%d-star player still has something to earn at level 100" % stars)


func test_garden_is_not_finished_early() -> void:
	# Even a perfect player keeps buying into the Expert levels instead of finishing early.
	var r := _simulate(3)
	t.check(r.last_buy >= 80, "3-star player's last garden purchase is at level %d (want 80+)" % r.last_buy)


func test_harder_levels_pay_more() -> void:
	var pay := CGGame.SEEDS_FIRST_CLEAR_BY_LABEL
	t.check(pay.Easy < pay.Medium and pay.Medium < pay.Hard and pay.Hard < pay.Expert)
