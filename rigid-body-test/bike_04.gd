extends CharacterBody3D


@export var min_speed: float = 10.0
@export var max_speed: float = 50.0

@export var turn_speed: float = 0.75
@export var level_speed: float = 3.0
@export var acceleration: float = 6.0

var forward_speed = 0
var target_speed = 0

var turn_input = 0
