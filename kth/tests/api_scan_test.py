import os as _wos  # portable root (handoff): WOWDEV_ROOT or the nearest parent dir holding foreverdump/
def _wowdev_root():
    r = _wos.environ.get("WOWDEV_ROOT")
    if r:
        return r
    d = _wos.path.dirname(_wos.path.abspath(__file__))
    while d != _wos.path.dirname(d) and not _wos.path.isdir(_wos.path.join(d, "foreverdump")):
        d = _wos.path.dirname(d)
    return d
_WROOT = _wowdev_root()
"""forever.3 R6: static Forever API scan. Every global the addon tree reads (luac GETGLOBAL) must be in ForeverDump's
static global-function list (tests/forever_static.json, from the run10 SV: v1/apis + docs/undocumentedGlobals) or be
reviewed below. A new unreviewed name fails the test (that is how the CheckBox SetDesaturation miss would be caught)."""
import subprocess, sys
REVIEWED = {
    # not functions (the static list only names functions): tables, frames, fonts, constants, strings
    'tables/frames/constants': '''ACCEPT CANCEL CLOSE OKAY NOT_BOUND COMBATLOG_OBJECT_AFFILIATION_OUTSIDER COMBATLOG_OBJECT_REACTION_FRIENDLY
      COMBATLOG_OBJECT_REACTION_HOSTILE COMBATLOG_OBJECT_TYPE_NPC COMBATLOG_OBJECT_TYPE_PLAYER C_CombatLogInternal C_CreatureInfo
      C_NamePlate C_PvP C_SettingsUtil C_Spell C_Timer ChatFontNormal ChatFrameUtil ChatTypeInfo ColorPickerFrame DEFAULT_CHAT_FRAME
      FONT_COLOR_CODE_CLOSE GAME_LOCALE GameFontDisableSmall GameFontHighlight GameFontHighlightLarge GameFontHighlightSmall
      GameFontNormal GameFontNormalSmall GameTooltip InterfaceOptionsFramePanelContainer LE_PARTY_CATEGORY_HOME
      LE_PARTY_CATEGORY_INSTANCE MAX_CLASSES NORMAL_FONT_COLOR OpacitySliderFrame RAID_CLASS_COLORS RaidWarningFrame
      SELECTED_CHAT_FRAME Settings SlashCmdList StaticPopupDialogs UIERRORS_HOLD_TIME UIErrorsFrame UIParent WOW_PROJECT_ID
      WOW_PROJECT_MAINLINE hash_SlashCmdList LibStub DecursiveRootTable testErrorCapturing
      C_DamageMeter Enum''', # forever.5: C_DamageMeter measured present on Forever (FD runs 16-18), read behind type checks
    # functions absent on Forever, each read only behind an existence guard or a Forever shim
    'guarded/shimmed functions': '''SetDesaturation GetSpellInfo FillLocalizedClassList CombatLogGetCurrentEventInfo
      AceGUIEditBoxInsertLink AceGUIMultiLineEditBoxInsertLink''',
}
OK = set(' '.join(REVIEWED.values()).split())
out = subprocess.run([sys.executable, _WROOT + '/kth/tools/globalscan.py', _WROOT + '/kth/port/KTH'], capture_output=True, text=True).stdout
names = [l.split()[0] for l in out.splitlines() if l.strip()]
new = [n for n in names if n not in OK]
print('R6', 'ok' if not new else 'FAIL', f'{len(names)} non-listed globals, all reviewed' if not new else f'unreviewed: {new}')
sys.exit(1 if new else 0)
