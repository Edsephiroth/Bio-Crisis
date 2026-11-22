# Bio Crisis: Dark Metropolis (Godot 4)

RPG de Ação e Survival Horror inspirado em **Parasite Eve**, construído em **Godot 4.3 + GDScript (tipagem estática)**.

## Jogar / Testar no Celular (Build Automático)
Cada push na branch `main` dispara o workflow [deploy-web.yml](.github/workflows/deploy-web.yml) que exporta a versão Web (HTML5, single-thread) para o GitHub Pages:

`https://edsephiroth.github.io/Bio-Crisis/`

> **Nota de primeira ativação:** No GitHub, vá em **Settings → Pages → Source** e selecione **GitHub Actions** (caso ainda não esteja ativo).

## Controles
* **Celular (Touch)**: Joystick virtual (canto inferior esquerdo), botão **TÁTICO** (canto inferior direito) quando a barra ATB estiver cheia, e toque direto nos inimigos dentro da esfera de alcance (ou botão **ATIRAR**).
* **PC (Teclado/Mouse)**:
  * `WASD` / `Setas`: Mover Elisabeth
  * `Espaço`: Ativar/Cancelar Pausa Tática ATB (exibe a esfera de alcance)
  * `Clique Esquerdo`: Selecionar alvo dentro da esfera
  * `E`: Energy Shot (30 PE — feixe perfurante)
  * `Q`: Heal (30 PE)
  * `R`: Haste (25 PE — dobra velocidade da ATB)

## Arquitetura do Projeto
```text
Bio-Crisis/
├── assets/
│   ├── sprites/      # Spritesheets otimizados (Elisabeth 8x4, Deformed Common 6x2)
│   ├── tilesets/     # Tilesets 48x48 do Salão de Festas (ONG Children First)
│   ├── icons/        # Ícones de armas, armaduras e suprimentos
│   ├── lights/       # Texturas radiais para PointLight2D
│   └── ui/           # Arte de título e retrato da Elisabeth
├── shaders/          # Vinheta e scanlines PS1 (crt_vignette.gdshader)
├── src/
│   ├── autoload/     # EventBus (sinais globais) e GameState (ATB, PE, EXP, armas)
│   ├── resources/    # Classes tipadas (WeaponData, PeSkillData, EnemyData)
│   ├── entities/     # Elisabeth (player) e EnemyBase (Deformed Common)
│   ├── levels/       # ChildrenFirstHall (Salão de Gala + Safe Room + Iluminação 2D)
│   └── ui/           # TitleScreen, HUD estilo Parasite Eve e VirtualJoystick
└── .github/workflows/deploy-web.yml
```
