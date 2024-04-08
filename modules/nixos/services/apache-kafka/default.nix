{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.apache-kafka;
in {
  options.campground.services.apache-kafka = with types; {
    enable = mkBoolOpt false "Enable Kafka;";

    # settings = mkOption {
    #   description = lib.mdDoc ''
    #     [Kafka broker configuration](https://kafka.apache.org/documentation.html#brokerconfigs)
    #     {file}`server.properties`.
    #
    #     Note that .properties files contain mappings from string to string.
    #     Keys with dots are NOT represented by nested attrs in these settings,
    #     but instead as quoted strings (ie. `settings."broker.id"`, NOT
    #     `settings.broker.id`).
    #  '';
    #   type = types.submodule {
    #     freeformType = with types; let
    #       primitive = oneOf [bool int str];
    #     in lazyAttrsOf (nullOr (either primitive (listOf primitive)));
    #
    #     options = {
    #       "broker.id" = mkOption {
    #         description = lib.mdDoc "Broker ID. -1 or null to auto-allocate in zookeeper mode.";
    #         default = null;
    #         type = with types; nullOr int;
    #       };
    #
    #       "log.dirs" = mkOption {
    #         description = lib.mdDoc "Log file directories.";
    #         # Deliberaly leave out old default and use the rewrite opportunity
    #         # to have users choose a safer value -- /tmp might be volatile and is a
    #         # slightly scary default choice.
    #         # default = [ "/tmp/apache-kafka" ];
    #         type = with types; listOf path;
    #       };
    #
    #       "listeners" = mkOption {
    #         description = lib.mdDoc ''
    #           Kafka Listener List.
    #           See [listeners](https://kafka.apache.org/documentation/#brokerconfigs_listeners).
    #         '';
    #         type = types.listOf types.str;
    #         default = [ "PLAINTEXT://localhost:9092" ];
    #       };
    #     };
    #   };
    # };

    # clusterId = mkOption {
    #   description = lib.mdDoc ''
    #     KRaft mode ClusterId used for formatting log directories. Can be generated with `kafka-storage.sh random-uuid`
    #   '';
    #   type = with types; nullOr str;
    #   default = null;
    # };
  };

  config = mkIf cfg.enable {
    services.apache-kafka = {
      enable = true; # Enables the Apache Kafka service.

      settings = {
        "broker.id" = 1; # Sets the broker ID to 1.
        "log.dirs" = [ "/var/lib/kafka/logs" ]; # Specifies the directory for log files.
        "listeners" = [ "PLAINTEXT://:9092" ]; # Configures Kafka to listen on port 9092 for all interfaces.
        "num.network.threads" = 3; # Number of threads for network requests.
        "num.io.threads" = 8; # Number of threads for I/O operations.
        "socket.send.buffer.bytes" = 102400; # The send buffer (SO_SNDBUF) used by the socket server.
        "socket.receive.buffer.bytes" = 102400; # The receive buffer (SO_RCVBUF) used by the socket server.
        "socket.request.max.bytes" = 104857600; # The maximum size of a request that the socket server will accept.
        "zookeeper.connect" = "localhost:2181"; # Zookeeper connection string.
      };

      jvmOptions = [
        "-Xmx1G" # Sets the maximum size of the memory allocation pool.
        "-Xms1G" # Sets the initial memory allocation pool.
      ];
    };
  };
}
