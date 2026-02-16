**Otimizações rápidas para Android Studio (projeto `estou-aqui`)**

- **Gradle (já aplicado):** as propriedades que aceleram builds estão em `app/android/gradle.properties`:
  - `org.gradle.daemon=true`
  - `org.gradle.parallel=true`
  - `org.gradle.configureondemand=true`
  - `org.gradle.caching=true`
  - `org.gradle.jvmargs` com `-XX:+UseG1GC` e `-Dfile.encoding=UTF-8`

- **VM Options do Studio:** copie o conteúdo de `.dev/android-studio-vmoptions.txt` em `Help → Edit Custom VM Options...` do Android Studio e reinicie.

- **Desativar plugins/inspeções:** abra `Settings → Plugins` e desative plugins não usados (Flutter/Dart só se não estiver trabalhando com Flutter no Studio). Em `Settings → Editor → Inspections` desative inspeções caras que não usa.

- **Inspeções e plugins recomendados para desativar (rápido):**
  - Plugins: `Kotlin` (se não estiver desenvolvendo Kotlin), `Android NDK Support` (se não usar NDK), plugins de tradução/tema pesados.
  - Inspeções: em `Settings → Editor → Inspections` desmarque ou reduza a severidade de `Performance`, `Probable bugs`, `Redundant code` e inspeções de `Kotlin`/`Java` que você não utiliza ativamente.
  - Dica: use `Analyze → Inspect Code...` apenas quando necessário; evite inspeções automáticas em tempo real para grandes projetos.


- **Configurações do Gradle no Studio:** em `Settings → Build, Execution, Deployment → Build Tools → Gradle` marque:
  - `Offline work` (quando não precisar baixar dependências)
  - `Gradle JDK` use uma JDK 17+ dedicada (não a embarcada) se possível

- **Disk/IO:** certifique-se que o Android Studio e o diretório do projeto não estão em partições montadas em rede; SSD é preferível.

- **Monitoramento:** comandos úteis:
  - `./gradlew --status` — estado do daemon Gradle
  - `./gradlew assembleDebug --scan` — para analisar build lenta
  - `jcmd <pid> VM.flags` ou `jcmd <pid> GC.run` — depuração JVM

- **Observações:** após aplicar `studio.vmoptions`, reinicie o Studio. Para mudanças no `gradle.properties` limpe cache do Gradle: `./gradlew --stop && ./gradlew cleanBuildCache`.
