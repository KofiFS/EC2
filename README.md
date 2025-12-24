# EC2 Space Combat - Godot 4

A 2D physics-based space combat game built in Godot 4.

## Core Mechanics

- **Physics-Based Movement**: Players control space rocks using WASD to apply directional forces
- **Momentum Combat**: Collisions deal damage based on impact force differential
  - Impact Force = Mass × Velocity
  - The rock with LESS momentum takes damage equal to the difference
  - The rock with MORE momentum wins the collision unscathed
- **Multiplayer**: Up to 10 players in networked matches

## Controls

| Key | Action |
|-----|--------|
| W / ↑ | Apply force upward |
| S / ↓ | Apply force downward |
| A / ← | Apply force left |
| D / → | Apply force right |

## Project Structure

```
EC2_Godot/
├── project.godot           # Project configuration
├── scenes/
│   ├── main.tscn          # Main game scene
│   ├── space_rock/
│   │   └── space_rock.tscn # Player rock scene
│   └── ui/
│       └── lobby.tscn     # Host/Join UI
├── scripts/
│   ├── autoloads/
│   │   ├── network_manager.gd  # Multiplayer handling
│   │   └── game_manager.gd     # Game state & spawning
│   ├── player/
│   │   └── space_rock.gd       # Player physics & damage
│   ├── ui/
│   │   └── lobby.gd            # Lobby UI logic
│   └── main.gd                 # Main scene controller
└── assets/                     # Sprites, shaders, audio
```

## How to Play

1. Open the project in Godot 4.3+
2. Press F5 to run the game
3. **To Host**: Click "HOST GAME"
4. **To Join**: Enter the host's IP address and click "JOIN GAME"
5. Use WASD to move and collide with other players!

## Networking

- Uses Godot's built-in ENet multiplayer
- Server-authoritative collision damage
- MultiplayerSynchronizer for state replication
- Default port: 7777

## Configuration

### SpaceRock Properties (space_rock.gd)

| Property | Default | Description |
|----------|---------|-------------|
| force_multiplier | 5000.0 | Force applied per input |
| max_velocity | 800.0 | Speed cap |
| max_health | 1000.0 | Damage before destruction |
| damage_scale | 0.01 | Scales physics force to damage |

### Physics Settings (project.godot)

| Setting | Value |
|---------|-------|
| Gravity | 0, 0 (disabled) |
| Linear Damp | 0.1 |
| Angular Damp | 0.5 |

## Extending the Game

### Adding Visual Effects

1. Add GPUParticles2D to space_rock.tscn for trails
2. Create shaders in assets/shaders/ for glow effects
3. Use AnimationPlayer for impact squash/stretch

### Adding Sound

1. Add AudioStreamPlayer2D nodes
2. Create collision sound effects
3. Trigger sounds in _on_body_entered()

### Adding Power-ups

1. Create a new scene with Area2D
2. Detect collision with SpaceRock
3. Modify rock properties (mass, speed, etc.)

## License

This project is for educational/recreational purposes.

