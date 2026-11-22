# Bio Crisis: Dark Metropolis (Godot 4)

RPG de Ação e Survival Horror inspirado em **Parasite Eve**, construído em **Godot 4.3 + GDScript (tipagem estática)**.

## Jogar / Testar no Celular ou PC
* **Versão Web (atualizada automaticamente a cada push):**
  `https://edsephiroth.github.io/Bio-Crisis/`
* **APK Android (sob demanda):**
  No GitHub, acesse **Actions → Build Bio Crisis (Android APK) → Run workflow** e baixe o artefato `BioCrisis-Android-APK`.

## O que está implementado (Prólogo — ONG Children First)
* **3 Salas Conectadas**: *Salão de Gala* (Safe Room + Terminal de Save) → *Corredor Leste* (Keycard de Evacuação + Tool) → *Hall Principal* (Chefe **Mutante Alfa** em 2 fases com Onda de Choque Bioelétrica).
* **Combate Tático ATB + Esfera de Alcance**: pausa tática, mira por toque/clique, 5 armas com munição por calibre (`9mm`, `12G`, `5.56mm`), *muzzle flash* e impacto visual.
* **Energia Bio-Celular (PE)**: `HEAL 1`, `ENERGY SHOT` (perfurante), `HASTE`, `SCAN`, `SLOW`, `BARRIER` e `LIBERATE`.
* **Bio-Crisis OS ModernMenu (6 abas)**: `INVENTORY` (com **Weapon Tune** via Tool), `MAP` (planta tática ao vivo), `BIO-ENERGY`, `STATUS / TUNE` (evolução biológica com BP), `EXTRAS` (Documentos + Bestiário) e `OPTIONS` (Áudio, CRT, Save/Load).
* **Atmosfera Survival Horror**: iluminação 2D em GPU com sombras dinâmicas (`LightOccluder2D`), partículas atmosféricas, animação Idle e de caminhada da Elisabeth, `NavigationAgent2D` (*pathfinding* real) e 14 faixas de áudio (SFX + BGM ambiente).

## Controles
* **Celular (Touch)**: Joystick virtual (esquerda), botão **TÁTICO** (direita), **INTERAGIR** (ao chegar perto de portas/itens) e **MENU** (topo direito).
* **PC**: `WASD`/Setas (mover), `Espaço` (Pausa Tática ATB), `F`/`Enter` (Interagir), `Clique` (atacar alvo), `E` (Energy Shot), `Q` (Heal), `R` (Haste).
