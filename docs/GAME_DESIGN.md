# Bio Crisis: Dark Metropolis — Documento Vivo de Game Design

Este documento registra as decisões autorais oficiais do **Bio Crisis**, consolidando sua identidade própria (descolada de *Parasite Eve*).

---

## 1. Identidade da Protagonista (Elisabeth Shelley)
* **Mulher comum do início ao fim**: Elisabeth é uma professora de inglês comum, **sem poderes sobrenaturais, mutações ou habilidades mitocondriais**.
* **Movimentação realista**:
  * **Andar (padrão)** em **8 direções** (cardinais + diagonais).
  * **Correr** segurando `Shift` (PC) ou empurrando o joystick virtual além de 75% (celular).
  * **Esquiva / Arranque (`Ctrl` / botão `DASH`)**: movimento puramente físico/humano, **sem rastros mágicos ou efeitos sobrenaturais** (usará animação dedicada de esquiva; provisoriamente usa frames acelerados de corrida).

---

## 2. Tecnologia Secreta da ONG *Children First* (Substituindo "Parasite Energy")
Em vez de poderes biológicos da protagonista, o sistema de habilidades táticas vem de **protótipos portáteis desenvolvidos secretamente pela ONG *Children First***, alimentados por uma **Bateria / Carga Tática** (recarregável continuamente em campo e mais rápido em terminais/Safe Rooms).

### Módulos Portáteis Planejados (Evolução do Sistema)
| Papel Tático | Módulo Tecnológico *Children First* | Função em Combate |
| :--- | :--- | :--- |
| **Cura** | **Injetor Nanomédico** | Aplicação rápida de nanossoro regenerativo para restaurar HP. |
| **Aceleração** | **Estimulante Adrenal** | Microdose controlada de adrenalina sintética que acelera movimento e recarga da barra ATB. |
| **Ataque Perfurante** | **Pulso PEM / Taser de Alta Tensão** | Descarga eletromagnética direcional que atravessa inimigos em linha reta (sinergia com alvos criogenizados/lentos). |
| **Defesa** | **Escudo Balístico / Campo Defletor** | Emissor portátil que gera barreira de campo reduzindo o dano físico recebido. |
| **Análise** | **Drone / Scanner Biométrico** | Escaneia pontos fracos, HP exato e padrão de ataque das ameaças na sala. |
| **Desaceleração** | **Granada / Emissor Criogênico** | Reduz drasticamente a mobilidade dos inimigos na área. |
| **Purificação** | **Antídoto / Purificador Químico** | Neutraliza toxinas (`Poison`), cegueira (`Darkness`) e paralisia (`Stiff`). |
| **Sobrecarga** | **Descarga de Capacitância Total** | Libera toda a carga da bateria em um pulso de área devastador em emergências. |

---

## 3. Sistema de Combate 2.0 (Pilares Aprovados)
* **Combate híbrido Tempo Real + Pausa Tática ATB** com **esfera de alcance** (100% de dano dentro da esfera + falloff progressivo fora dela).
* **Comportamentos reais por classe de arma**:
  * **SMG (MP5A5)**: rajada rápida de 5 tiros em sequência com dano dividido entre os impactos.
  * **Pistola Rajada (M93R)**: 3 tiros rápidos em sequência com dano dividido.
  * **Shotgun (M870)**: leque/cone de 5 estilhaços simultâneos atingindo múltiplos alvos.
  * **Rifle (M4A1)** e **Pistola Semi (Glock 19)**: disparos precisos controlados.
* **Pente (Magazine) + Recarga Tática (`C`)** separados da munição reserva por calibre.
* **Perks & Modificadores transferíveis (Tune)** com personalidade própria do *Bio Crisis* + combos de **Bio-Ressonância**.
* **Inimigos visíveis no mapa + Lockdown Tático** em salas de emboscada/chefe com troca dinâmica de música.
* **Chefes com Partes Destrutíveis** (*Braços*, *Corpo*, *Núcleo*), **Status Negativos** (`Poison`, `Darkness`, `Stiff`), **Drops no chão** e **Aftermath**.

## 4. Proficiência Invisível & Coice Realista
* **Sem barras nem números na UI**: Elisabeth começa inexperiente com armas pesadas (especialmente a **Shotgun M870**), sofrendo empurrão físico de coice para trás, breve pausa de recuperação de postura e cone mais aberto.
* **Evolução orgânica sentida na gameplay**: conforme ela usa cada classe de arma (`shotgun`, `rifle`, `smg`, `pistol`), um índice oculto (`weapon_familiarity`, persistido no Save) reduz gradualmente o coice, estabiliza a postura, fecha a dispersão e deixa a cadência mais firme.
* **Pistolas cadenciadas**: tiros mais pausados (`Glock 19` e `M93R`) contrastando com a rajada rápida da `MP5A5` e o coice pesado da `M870`.
