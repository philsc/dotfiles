# Inspired by
# https://github.com/dst-academy/docker-dontstarvetogether/blob/develop/docs/examples/shard/docker-compose.yml

{% set dst_version = '0.8.0' %}

dontstarvetogether_image_build:
  cmd.run:
    - name: docker build --build-arg MODS=378160973 --tag phil/dontstarvetogether:{{ dst_version }} https://github.com/dst-academy/docker-dontstarvetogether.git#v{{ dst_version }}:build
    - unless:
      - docker image inspect phil/dontstarvetogether:{{ dst_version }} > /dev/null

dst_overworld_volume:
  dockerng.volume_present

dst_underworld_volume:
  dockerng.volume_present

dst_overworld:
  dockerng.running:
    - image: phil/dontstarvetogether:{{ dst_version }}
    - watch:
      - cmd: dontstarvetogether_image_build
      - dockerng: dst_overworld_volume
    - hostname: overworld
    - tty: True
    - interactive: True
    - command: dst-server start --update=all
    - environment:
      - LEVELDATA_OVERRIDES: |
          return {
            desc="Schrader portal",
            hideminimap=false,
            id="SURVIVAL_TOGETHER",
            location="forest",
            max_playlist_position=999,
            min_playlist_position=0,
            name="Default",
            numrandom_set_pieces=4,
            ordered_story_setpieces={ "Sculptures_1", "Maxwell5" },
            override_level_string=false,
            overrides={
              alternatehunt="default",
              angrybees="default",
              antliontribute="default",
              autumn="longseason",
              bearger="default",
              beefalo="default",
              beefaloheat="default",
              bees="default",
              berrybush="often",
              birds="default",
              boons="default",
              branching="default",
              butterfly="default",
              buzzard="default",
              cactus="default",
              carrot="often",
              catcoon="default",
              chess="default",
              day="longday",
              deciduousmonster="default",
              deerclops="default",
              disease_delay="default",
              dragonfly="default",
              flint="often",
              flowers="often",
              frograin="rare",
              goosemoose="default",
              grass="often",
              houndmound="default",
              hounds="rare",
              hunt="default",
              krampus="default",
              layout_mode="LinkNodesByKeys",
              liefs="default",
              lightning="default",
              lightninggoat="default",
              loop="default",
              lureplants="default",
              marshbush="default",
              merm="default",
              meteorshowers="default",
              meteorspawner="default",
              moles="default",
              mushroom="default",
              penguins="default",
              perd="default",
              petrification="default",
              pigs="default",
              ponds="default",
              prefabswaps_start="default",
              rabbits="often",
              reeds="default",
              regrowth="default",
              roads="default",
              rock="default",
              rock_ice="default",
              sapling="default",
              season_start="default",
              specialevent="default",
              spiders="default",
              spring="shortseason",
              start_location="default",
              summer="default",
              tallbirds="default",
              task_set="default",
              tentacles="default",
              touchstone="always",
              trees="default",
              tumbleweed="default",
              walrus="default",
              weather="rare",
              wildfires="default",
              winter="default",
              world_size="default",
              wormhole_prefab="wormhole"
            },
            random_set_pieces={
              "Sculptures_2",
              "Sculptures_3",
              "Sculptures_4",
              "Sculptures_5",
              "Chessy_1",
              "Chessy_2",
              "Chessy_3",
              "Chessy_4",
              "Chessy_5",
              "Chessy_6",
              "Maxwell1",
              "Maxwell2",
              "Maxwell3",
              "Maxwell4",
              "Maxwell6",
              "Maxwell7",
              "Warzone_1",
              "Warzone_2",
              "Warzone_3"
            },
            required_prefabs={ "multiplayer_portal" },
            substitutes={  },
            version=3
          }
      - TOKEN: {{ pillar["dontstarvetogether_token"] }}
      - NAME: PhilWorld
      - DESCRIPTION: "The world's coziest place!"
      - PASSWORD: {{ pillar["dontstarvetogether_password"] }}
      - ADMINLIST: {{ pillar["dontstarvetogether_admins"] }}
      - GAME_MODE: endless
      - INTENTION: cooperative
      - PAUSE_WHEN_EMPTY: "true"
      - SHARD_ENABLE: "true"
      - SHARD_NAME: overworld
      - SHARD_IS_MASTER: "true"
      - SHARD_MASTER_IP: overworld
      - SHARD_CLUSTER_KEY: {{ pillar["dontstarvetogether_cluster_key"] }}
      # Keep in sync with dontstarvetogether/docker/Dockerfile.
      - MODS_OVERRIDES: |
          return {
            ['workshop-378160973'] = { enabled = true },
          }
    - port_bindings:
      - "10999:10999/udp"
    - binds:
      - dst_overworld_volume:/var/lib/dsta/cluster:rw

dst_underworld:
  dockerng.running:
    - image: phil/dontstarvetogether:{{ dst_version }}
    - watch:
      - cmd: dontstarvetogether_image_build
      - dockerng: dst_underworld_volume
    - hostname: underworld
    - tty: True
    - interactive: True
    - command: dst-server start --update=all
    - environment:
      - LEVELDATA_OVERRIDES: |
          return {
            background_node_range={ 0, 1 },
            desc="Delve into the caves... together!",
            hideminimap=false,
            id="DST_CAVE",
            location="cave",
            max_playlist_position=999,
            min_playlist_position=0,
            name="The Caves",
            numrandom_set_pieces=0,
            override_level_string=false,
            overrides={
              banana="often",
              bats="default",
              berrybush="often",
              boons="default",
              branching="default",
              bunnymen="default",
              cave_ponds="default",
              cave_spiders="default",
              cavelight="default",
              chess="default",
              disease_delay="default",
              earthquakes="rare",
              fern="default",
              fissure="default",
              flint="often",
              flower_cave="default",
              grass="often",
              layout_mode="RestrictNodesByKey",
              lichen="default",
              liefs="default",
              loop="default",
              marshbush="default",
              monkey="default",
              mushroom="default",
              mushtree="default",
              petrification="default",
              prefabswaps_start="default",
              reeds="default",
              regrowth="default",
              roads="never",
              rock="default",
              rocky="default",
              sapling="default",
              season_start="default",
              slurper="default",
              slurtles="default",
              start_location="caves",
              task_set="cave_default",
              tentacles="default",
              touchstone="default",
              trees="default",
              weather="rare",
              world_size="default",
              wormattacks="rare",
              wormhole_prefab="tentacle_pillar",
              wormlights="default",
              worms="default"
            },
            required_prefabs={ "multiplayer_portal" },
            substitutes={  },
            version=3
          }
      - TOKEN: {{ pillar["dontstarvetogether_token"] }}
      - NAME: Underworld
      - GAME_MODE: endless
      - INTENTION: cooperative
      - SERVER_PORT: "11000"
      - SHARD_ENABLE: "true"
      - SHARD_NAME: underworld
      - SHARD_IS_MASTER: "false"
      - SHARD_MASTER_IP: overworld
      - SHARD_CLUSTER_KEY: {{ pillar["dontstarvetogether_cluster_key"] }}
    - port_bindings:
      - "11000:11000/udp"
    - links:
      - dst_overworld:dst_link
    - binds:
      - dst_underworld_volume:/var/lib/dsta/cluster:rw
