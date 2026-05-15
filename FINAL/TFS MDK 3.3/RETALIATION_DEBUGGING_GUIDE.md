# TFS MDK 3.1 - Pokémon Retaliation Debugging Guide

## Quick Symptom Checklist

### Symptom 1: No Attack at All
If wild Pokémon never attacks back:
- [ ] Monster is not being marked as idle=false
- [ ] Monster is in ZONE_PROTECTION
- [ ] Attacker is in ZONE_PROTECTION  
- [ ] `isOpponent()` returning false (check master relationship)
- [ ] `canSeeCreature()` failing (z-level mismatch or distance)
- [ ] Monster has 0 HP

**Debug with:** Add console logging in `onAttacked()` and `selectTarget()`

### Symptom 2: Delayed Attack (1-2 seconds)
If attack happens but with visible delay:
- [ ] This is NORMAL after the fix (one onThink cycle)
- [ ] Expected: <100ms now (was ~500-2000ms before)
- [ ] onThink interval config might need tuning

**Expected behavior:** Visual confirmation of hit + immediate retaliation within 1 frame

### Symptom 3: Inconsistent Attacks
If sometimes attacks and sometimes doesn't:
- [ ] Check if Pokemon becomes idle mid-fight
- [ ] Verify targetList management (add/remove)
- [ ] Check for race conditions with concurrent attacks

---

## Debug Logging Steps

### Add Logging to monster.cpp

```cpp
void Monster::onAttacked()
{
	std::cout << "[DEBUG] " << getName() << " was attacked! (isIdle=" << isIdle 
	          << ", lastHitCreatureId=" << lastHitCreatureId << ")" << std::endl;
	
	setIdle(false);

	if (lastHitCreatureId == 0) {
		std::cout << "[DEBUG] " << getName() << " - lastHitCreatureId is 0!" << std::endl;
		return;
	}

	Creature* attacker = g_game.getCreatureByID(lastHitCreatureId);
	if (!attacker) {
		std::cout << "[DEBUG] " << getName() << " - attacker pointer is NULL!" << std::endl;
		return;
	}
	
	if (!isOpponent(attacker)) {
		std::cout << "[DEBUG] " << getName() << " - " << attacker->getName() 
		          << " is not opponent!" << std::endl;
		return;
	}

	std::cout << "[DEBUG] " << getName() << " - Adding " << attacker->getName() 
	          << " to target list" << std::endl;
	
	if (std::find(targetList.begin(), targetList.end(), attacker) == targetList.end()) {
		addTarget(attacker, true);
		std::cout << "[DEBUG] " << getName() << " - Target added, calling selectTarget()" << std::endl;
	}

	bool selected = selectTarget(attacker);
	std::cout << "[DEBUG] " << getName() << " - selectTarget returned: " << selected << std::endl;
}
```

### Check selectTarget() Path

Also add logging to `selectTarget()`:
```cpp
bool Monster::selectTarget(Creature* creature)
{
	std::cout << "[DEBUG selectTarget] Checking " << creature->getName() << std::endl;
	
	if (!isTarget(creature)) {
		std::cout << "[DEBUG selectTarget] FAIL: isTarget() = false" << std::endl;
		return false;
	}

	auto it = std::find(targetList.begin(), targetList.end(), creature);
	if (it == targetList.end()) {
		std::cout << "[DEBUG selectTarget] FAIL: not in targetList (size=" << targetList.size() << ")" << std::endl;
		return false;
	}

	if (isPassive()) {
		std::cout << "[DEBUG selectTarget] Monster is PASSIVE, checking hasBeenAttacked()" << std::endl;
		if (creature->getMaster() && creature->getMaster()->getPlayer()) {
			if (!hasBeenAttacked(creature->getMaster()->getPlayer()->getID())) {
				std::cout << "[DEBUG selectTarget] FAIL: hasBeenAttacked(master) = false" << std::endl;
				return false;
			}
		} else {
			if(!hasBeenAttacked(creature->getID())) {
				std::cout << "[DEBUG selectTarget] FAIL: hasBeenAttacked(creature) = false" << std::endl;
				return false;
			}
		}
	}

	std::cout << "[DEBUG selectTarget] SUCCESS: Attacking " << creature->getName() << std::endl;

	if (isHostile() || isSummon()) {
		if (setAttackedCreature(creature) && (!isSummon() || isMonsterGuardian())) {
			g_dispatcher.addTask(createTask(std::bind(&Game::checkCreatureAttack, &g_game, getID())));
		}
	}
	return setFollowCreature(creature);
}
```

---

## Common Issues & Solutions

### Issue: "isOpponent() returning false"

**Causes:**
- Pokémon is isFriend() (check master relationships)
- Pokémon is another summon of same player
- isMonsterGuardian() check

**Solution:**
Check in `isFriend()` (monster.cpp):
```cpp
bool Monster::isFriend(const Creature* creature) const
{
	// Check if guardian
	if (creature->isMonsterGuardian()) {
		return true;
	}

	// Check if summon of same player
	if (isSummon() && getMaster()->getPlayer()) {
		const Player* masterPlayer = getMaster()->getPlayer();
		const Player* tmpPlayer = nullptr;

		if (creature->getPlayer()) {
			tmpPlayer = creature->getPlayer();
		} else {
			const Creature* creatureMaster = creature->getMaster();
			if (creatureMaster && creatureMaster->getPlayer()) {
				tmpPlayer = creatureMaster->getPlayer();
			}
		}

		if (tmpPlayer && (tmpPlayer == masterPlayer || masterPlayer->isPartner(tmpPlayer))) {
			return true;  // ← This prevents attack!
		}
	} else if (creature->getMonster() && !creature->isSummon()) {
		return true;  // ← Monsters don't attack each other!
	}

	return false;
}
```

**Fix:** For wild Pokémons vs player's Pokémons, verify:
- Wild is NOT a isSummon()
- Wild is NOT a isMonsterGuardian()

### Issue: "canSeeCreature() returning false"

**Causes:**
- Z-level difference > 2
- Player in ZONE_PROTECTION
- Monster/Player invisible
- Distance too far

**Check:**
```cpp
bool Creature::canSee(const Position& myPos, const Position& pos)
{
	if (myPos.z <= 7) {
		// Ground level view range 7-0
		if (pos.z > 7) return false;
	} else if (myPos.z >= 8) {
		// Underground view range ±2
		if (Position::getDistanceZ(myPos, pos) > 2) return false;
	}
	
	// Max viewport check (~20x20 tiles)
	const int_fast32_t offsetz = myPos.getZ() - pos.getZ();
	return (pos.getX() >= myPos.getX() - (Map::maxViewportX - 2) + offsetz) && 
	       (pos.getX() <= myPos.getX() + (Map::maxViewportX - 2) + offsetz) &&
	       (pos.getY() >= myPos.getY() - (Map::maxViewportY - 1) + offsetz) && 
	       (pos.getY() <= myPos.getY() + (Map::maxViewportY - 1) + offsetz);
}
```

**Solution:** Move player closer or ensure on same z-level.

### Issue: "hasBeenAttacked() returning false (Passive)"

**Causes:**
- damageMap entry expired (older than PZ_LOCKED time)
- Attacker ID mismatch (Master vs Player)
- damageMap entry never created

**Check timing:**
```cpp
bool Creature::hasBeenAttacked(uint32_t attackerId)
{
	auto it = damageMap.find(attackerId);
	if (it == damageMap.end()) {
		return false;  // ← Entry never added
	}
	// Entry older than PZ_LOCKED seconds = return false
	return (OTSYS_TIME() - it->second.ticks) <= g_config.getNumber(ConfigManager::PZ_LOCKED);
}
```

**Solution:** Verify addDamagePoints() is called before onAttacked().

---

## Performance Profiling

### Memory Impact
- `onAttacked()` creates no new allocations
- Uses existing `lastHitCreatureId` field
- Reuses existing `targetList` structure

### CPU Impact
- One extra function call per attack event
- One g_game.getCreatureByID() lookup
- One std::find() on targetList
- Should be < 1% CPU increase

**Measure with:**
```cpp
uint64_t start = OTSYS_TIME();
// onAttacked() code here
uint64_t elapsed = OTSYS_TIME() - start;
if (elapsed > 10) { // > 10ms
	std::cout << "[SLOW] onAttacked took " << elapsed << "ms" << std::endl;
}
```

---

## Configuration Tuning

### Retaliation Timing (config.lua)

```lua
-- Minimum time between retaliation attempts (milliseconds)
minimumRetaliationDelay = 0

-- Maximum targets a monster can track
maxCombatTargets = 5

-- Update target list interval (how often to search for new targets)
targetListUpdateInterval = 500
```

### Monster Behavior (monster XML)

For each Pokémon type in creatures.xml:
```xml
<monster name="Pikachu" ...>
    <health now="100" max="100"/>
    <flag summonable="0"/>
    <flag hostile="1"/>
    <flag passive="0"/>
    <!-- Higher speed = faster retaliation in onThink -->
    <targetchange interval="4000" chance="20"/>
</monster>
```

---

## Testing Checklist

### Unit Tests
- [ ] Test with Hostile Pokémon (hostile=1, passive=0)
- [ ] Test with Passive Pokémon (hostile=0, passive=1)
- [ ] Test with Summon (Pokémon caught by player)
- [ ] Test when attacker is protected
- [ ] Test when Pokémon is protected
- [ ] Test multi-floor scenarios

### Integration Tests
- [ ] Player attacks wild → Wild retaliates
- [ ] Summon attacks wild → Wild retaliates to summon
- [ ] Multiple attackers → Correct priority
- [ ] Ranged attacks → Works same as melee

### Regression Tests
- [ ] Summon behavior unchanged
- [ ] Guardian behavior unchanged
- [ ] NPC behavior unchanged
- [ ] Player vs Player unchanged

---

## Emergency Rollback

If issues occur, revert by:

1. **Restore original files:**
   ```bash
   git checkout src/monster.cpp src/monster.h
   ```

2. **Rebuild:**
   ```bash
   cmake . && make
   ```

3. **Monitor logs** for any residual issues

---

**Last Updated:** 2026-05-03  
**Status:** Ready for testing
