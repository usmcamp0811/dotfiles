{ lib, writeText, writeShellApplication, substituteAll, inputs, pkgs
, hosts ? { }, ... }:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  fuck-you-mac = pkgs.writeShellScriptBin "macsucks" ''
    cat ${flink-conf}
    echo "MAC IS STILL STUPID!!"
  '';
  flink-conf = pkgs.writeTextFile {
    name = "flink-conf.yaml";
    text = ''
      env.java.opts.all: --add-exports=java.base/sun.net.util=ALL-UNNAMED --add-exports=java.rmi/sun.rmi.registry=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.parser=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED --add-exports=java.security.jgss/sun.security.krb5=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.net=ALL-UNNAMED --add-opens=java.base/java.io=ALL-UNNAMED --add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/sun.nio.ch=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED --add-opens=java.base/java.text=ALL-UNNAMED --add-opens=java.base/java.time=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.base/java.util.concurrent=ALL-UNNAMED --add-opens=java.base/java.util.concurrent.atomic=ALL-UNNAMED --add-opens=java.base/java.util.concurrent.locks=ALL-UNNAMED
      jobmanager.rpc.address: localhost
      jobmanager.rpc.port: 6123
      jobmanager.bind-host: 0.0.0.0
      jobmanager.memory.process.size: 1600m
      taskmanager.bind-host: 0.0.0.0
      taskmanager.host: localhost
      taskmanager.memory.process.size: 1728m
      taskmanager.numberOfTaskSlots: 3
      parallelism.default:
      jobmanager.execution.failover-strategy: region
      rest.address: localhost
      rest.port: 8081
      rest.bind-address: 0.0.0.0
      env.log.dir: /tmp/flink-logs
      env.java.home: ${pkgs.openjdk11}
      env.path: ${python-env}/bin/:$PATH
      python.path: ${python-env}/lib/python3.11/site-packages
      python.executable: ${python-env}/bin/python
      python.client.executable: ${python-env}/bin/python
      pipeline.jars: ${pkgs.campground.flink-connector-kafka}
    '';
  };
in fuck-you-mac
