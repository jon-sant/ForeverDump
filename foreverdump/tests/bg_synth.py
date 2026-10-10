"""v2.2.10: synthetic BG-like event stream in the tools/fdump/bgreplay.py export format (fallback when no real capture
is on the box). Mix: DAMAGE_METER_* bursts (incl. secret args), raid UNIT_HEALTH, nameplate UNIT_AURA, regen toggles.
usage: python3 tests/bg_synth.py OUT.lua [N_ROWS]"""
import random
import sys


def synth_stream(path, n=6000, seed=2210):
    rnd = random.Random(seed)
    t0 = 500000.0
    rows, t = [], t0
    combat = False
    for k in range(n):
        t += rnd.choice((0.0, 0.0, 0.001, 0.033, 0.25))
        if k % 700 == 0:
            combat = not combat
            rows.append('{t=%.3f,e="%s",c=%s,n=0,a={}}' % (t, "PLAYER_REGEN_DISABLED" if combat else "PLAYER_REGEN_ENABLED",
                                                          "true" if combat else "false"))
        r = rnd.random()
        c = "true" if combat else "false"
        if r < 0.6:
            rows.append('{t=%.3f,e="DAMAGE_METER_COMBAT_SESSION_UPDATED",c=%s,n=2,a={%d,%d,}}'
                        % (t, c, rnd.choice((0, 1, 7, 10)), rnd.choice((0, 0, 0, 3))))
        elif r < 0.65:
            rows.append('{t=%.3f,e="DAMAGE_METER_CURRENT_SESSION_UPDATED",c=%s,n=0,a={}}' % (t, c))
        elif r < 0.7:
            rows.append('{t=%.3f,e="DAMAGE_METER_COMBAT_SESSION_UPDATED",c=%s,n=2,a={X,0,}}' % (t, c))
        elif r < 0.85:
            rows.append('{t=%.3f,e="UNIT_HEALTH",c=%s,n=1,a={"raid%d",}}' % (t, c, rnd.randint(1, 15)))
        else:
            rows.append('{t=%.3f,e="UNIT_AURA",c=%s,n=1,a={"nameplate%d",}}' % (t, c, rnd.randint(1, 20)))
    with open(path, "w") as f:
        f.write('return {meta={["captureSid"]="cap-synth-1",["startTime"]=%.3f,["stopTime"]=%.3f,'
                '["restrictionsAtStart"]={},["instanceType"]="pvp",},anchor={["epoch"]=1791500000,'
                '["gameTime"]=%.3f,["utcOffset"]=-14400,},events={\n' % (t0, t, t0))
        f.write(",\n".join(rows))
        f.write("\n}}\n")
    return t - t0


if __name__ == "__main__":
    print("%.1f s" % synth_stream(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 6000))
