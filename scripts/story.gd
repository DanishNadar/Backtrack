class_name Story
extends RefCounted
## All of the story's text, in the order it's told. Crawls are
## [title, body] pairs shown by crawl.gd; cutscenes are lists of beats played
## by cutscene.gd.
##
## Beat order: PROLOGUE crawl -> AWAKENING cutscene -> DREAM crawl ->
## nights 1..MEMORIES.size() (a MEMORIES crawl after each) -> FINALE crawl ->
## FINALE cutscene. Fading away at any point plays the FADED crawl instead.

const PROLOGUE := [
	"BACKTRACK\nThe Ragebaiter's Guide to the Void",
	"Demen (Anakin Gilgamesh John-Smith) was once a joyful young soul. He played outside every single day and got plenty of sunshine.\n\nUntil one day, his life changed forever.\n\nHe was 17 years old, playing ball on the street with a bunch of young folk, when a distracted driver hit him and sent him flying into a well.\n\nA wishing well.\n\nIn agonizing pain, he made his final wish: a daughter who was immortal.",
]

## Beats: "text" is the caption, "speaker" (optional) prefixes it, and
## "event" (optional) triggers an animation in the cutscene.
const AWAKENING := [
	{"text": "50 years later."},
	{"text": "Demen awakens from his coma. He doesn't know who he is, who the people around him are, or where he is."},
	{"speaker": "Doctor", "text": "You've been in a coma for 50 years."},
	{"speaker": "Demen", "text": "..."},
	{"speaker": "Doctor", "text": "This is your daughter."},
	{"speaker": "Daughter", "text": "Hi, Dad."},
	{"speaker": "Doctor", "text": "I'm sorry. You have dementia."},
]

const DREAM := [
	"THE MEMORY GAME",
	"That night, after learning he has dementia, Demen falls asleep.\n\nIn his dream he is a butterfly, faded and glowing, lost in the maze of his own brain.\n\nSomewhere in the dark are his memories. He must collect them, one night at a time.\n\nBut the mind stumbles backward, and every shortcut costs a piece of who he is.",
]

## One memory per night; the game ends after the last one.
const MEMORIES := [
	["CORE MEMORY I\nSunshine", "The sun on your face. Every single day, outside, until the streetlights came on.\n\nYou were a joyful young soul."],
	["CORE MEMORY II\nThe Ball", "A ball bouncing down the street. A bunch of young folk, laughing, shouting your name.\n\nYou can almost hear it."],
	["CORE MEMORY III\nThe Driver", "Headlights. A horn. A driver looking at something else.\n\nThen you were flying."],
	["CORE MEMORY IV\nThe Well", "Cold stone. Black water. Coins glinting in the dark.\n\nYou had fallen into a wishing well."],
	["CORE MEMORY V\nThe Wish", "In agonizing pain, you wished for one thing: a daughter who would never die.\n\nAnd with the wish came your name."],
]

const FINALE := [
	"50 YEARS LATER",
	"The dream lasted so long that another 50 years passed by.\n\nNight after night, Demen collected his memories, one pattern at a time, until he remembered who he was.\n\nAnd then, he woke up.",
]

const FINALE_SCENE := [
	{"text": "Demen wakes up. His daughter is at his side."},
	{"speaker": "Demen", "text": "My name is Anakin Gilgamesh John-Smith."},
	{"text": "Everyone in the room breaks into tears.", "event": "cry"},
	{"text": "Then the doctor is gone. In his place, a swarm of butterflies.", "event": "doctor_butterflies"},
	{"text": "His daughter is gone too. Only butterflies remain.", "event": "daughter_butterflies"},
	{"text": "THE END"},
]

const FADED := [
	"FADED AWAY",
	"Demen tried to skip the human connection and the learning process, and faded into irrelevancy.\n\nHis daughter pulled the plug.\n\nHe was a lost cause.",
]
