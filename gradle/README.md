# Gradle

## What it is

Global properties for Gradle, the JVM and Android build tool.

## Why it's here

Machine-wide build tuning (memory, parallelism, caching) so every Gradle build on this machine gets fast, sane defaults.

## Important: precedence warning

`~/.gradle/gradle.properties` takes PRECEDENCE over a project's own `gradle.properties`.
So this file holds only broadly-safe, machine-wide defaults.
Project-specific or risky settings (configuration-cache, `workers.max`, Kotlin/Native tuning) are deliberately left to each project.

## What's here

- `gradle.properties` -> `~/.gradle/gradle.properties` - tuned for an Apple M-series machine with 24 GB RAM.

It sets:

- Gradle daemon heap with G1GC and periodic GC so an idle daemon returns RAM to the OS.
- A separate Kotlin compile-daemon heap.
- Parallel builds, the build cache, and a warm daemon with a 30-minute idle timeout.
- Kotlin official code style and incremental compilation.
