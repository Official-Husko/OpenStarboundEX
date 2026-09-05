#pragma once

#include "StarWeightedPool.hpp"
#include "StarParticle.hpp"

namespace Star {

struct WeatherType {
  struct ParticleConfig {
    Particle particle;
    float density;
    bool autoRotate;
  };

  struct ProjectileConfig {
    String projectile;
    Json parameters;
    Vec2F velocity;
    float ratePerX;
    int spawnAboveRegion;
    int spawnHorizontalPad;
    float windAffectAmount;
  };

  WeatherType();
  WeatherType(Json config, String path = String());

  Json toJson() const;

  String name;

  List<ParticleConfig> particles;
  List<ProjectileConfig> projectiles;
  StringList statusEffects;

  float maximumWind;
  Vec2F duration;
  StringList weatherNoises;

  // Average number of lightning strikes per second at full weather
  // intensity. 0 (the default) disables lightning entirely for this weather
  // type - existing weather configs are unaffected unless they opt in.
  float lightningChance;
  // Thunderclap sounds to pick from when a strike occurs.
  StringList thunderSounds;
};

typedef WeightedPool<String> WeatherPool;

DataStream& operator>>(DataStream& ds, WeatherType& weatherType);
DataStream& operator<<(DataStream& ds, WeatherType const& weatherType);
}
