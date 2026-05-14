# Hister NixOS Module

A NixOS module for [Hister](https://github.com/asciimoo/hister) - Your own personal search engine for indexing and searching your browsing history and local files.

## Features

- **Full-text search**: Search through the actual content of web pages you've visited
- **Local file indexing**: Index your local knowledge base
- **Semantic search**: Optional AI-powered semantic search with embeddings
- **Multi-user support**: Host for multiple users with authentication
- **OAuth integration**: Support for GitHub, Google, and generic OIDC providers
- **Vault integration**: Secure secrets management for access tokens and API keys
- **Hardened systemd service**: Security-focused service configuration

## Quick Start

### Basic Configuration

```nix
{
  fmf.services.hister = {
    enable = true;
    server.address = "0.0.0.0:4433";
    server.baseUrl = "https://hister.example.com";
    openFirewall = true;
  };
}
```

### With Local File Indexing

```nix
{
  fmf.services.hister = {
    enable = true;
    
    indexer.directories = [
      {
        path = "~/notes";
        filetypes = [ "txt" "md" ];
      }
      {
        path = "~/Documents/wiki";
        filetypes = [ "md" "org" "txt" ];
        excludes = [ "*secret*" "*.tmp" ];
      }
    ];
  };
}
```

### With Semantic Search (Ollama)

```nix
{
  fmf.services.hister = {
    enable = true;
    
    semanticSearch = {
      enable = true;
      embeddingEndpoint = "http://localhost:11434/v1/embeddings";
      embeddingModel = "nomic-embed-text";
      dimensions = 768;
      maxContextLength = 512;
      queryPrefix = "search_query: ";
      documentPrefix = "search_document: ";
    };
  };
}
```

### With Access Token (Vault)

```nix
{
  fmf.services.hister = {
    enable = true;
    
    # The access token value will be pulled from Vault
    app.accessToken = "placeholder"; # Any non-null value enables Vault integration
    
    # Vault configuration
    vault-path = "secret/campground/hister";
    kvVersion = "v2";
  };
}
```

**Important**: You need to store the actual token in Vault at the configured path:

```bash
vault kv put secret/campground/hister HISTER_ACCESS_TOKEN="your-secret-token"
```

### With OAuth (GitHub)

```nix
{
  fmf.services.hister = {
    enable = true;
    
    app.userHandling = true;
    
    server.oauth = {
      github = {
        client_id = "your-github-client-id";
        client_secret = "your-github-client-secret";
      };
    };
    
    # Optional: Only allow OAuth, disable password login
    server.oauthOnly = true;
  };
}
```

### With PostgreSQL

```nix
{
  fmf.services.hister = {
    enable = true;
    
    server.database = "host=localhost user=hister password=hister dbname=hister port=5432 sslmode=disable TimeZone=UTC";
  };
}
```

## Configuration Options

### App Settings (`app.*`)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `searchUrl` | string | `"https://google.com/search?q={query}"` | Fallback web search URL |
| `accessToken` | null or string | `null` | Access token for API authentication (stored in Vault) |
| `userHandling` | bool | `false` | Enable multi-user mode |
| `logLevel` | enum | `"info"` | Log level: debug, info, warn, error |
| `debugSql` | bool | `false` | Enable verbose SQL logging |
| `openResultsOnNewTab` | bool | `false` | Open results in new tab |
| `redirectOnNoResults` | bool | `true` | Redirect to searchUrl when no results |

### Server Settings (`server.*`)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `address` | string | `"127.0.0.1:4433"` | Host and port to listen on |
| `baseUrl` | null or string | `null` | Public URL of the instance |
| `database` | string | `"db.sqlite3"` | SQLite filename or PostgreSQL DSN |
| `oauth` | attrset | `{}` | OAuth provider configurations |
| `oauthOnly` | bool | `false` | Disable password login |

### Indexer Settings (`indexer.*`)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `detectLanguages` | bool | `true` | Enable automatic language detection |
| `directories` | list | `[]` | Local directories to index |
| `maxFileSizeMb` | int | `1` | Maximum file size to index (MB) |

### Crawler Settings (`crawler.*`)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `backend` | enum | `"http"` | Backend: http, chromedp, bidi |
| `backendOptions` | attrset | `{}` | Backend-specific options |
| `timeout` | int | `5` | Request timeout (seconds) |
| `delay` | int | `0` | Delay between requests (seconds) |
| `userAgent` | null or string | `"Hister"` | Custom User-Agent |
| `headers` | attrset | `{}` | Extra HTTP headers |
| `cookies` | list | `[]` | Cookies to send |
| `noRobots` | bool | `false` | Disable robots.txt compliance |

### Semantic Search Settings (`semanticSearch.*`)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable semantic search |
| `embeddingEndpoint` | string | `"http://localhost:11434/v1/embeddings"` | Embeddings API URL |
| `embeddingModel` | string | `"qwen3-embedding:8b"` | Model name |
| `apiKey` | null or string | `null` | API key (stored in Vault) |
| `dimensions` | int | `4096` | Vector dimensionality |
| `maxContextLength` | int | `4096` | Max tokens per chunk |
| `chunkOverlap` | int | `128` | Tokens shared between chunks |
| `queryPrefix` | string | `"query: "` | Query prefix for embeddings |
| `documentPrefix` | string | `""` | Document prefix for embeddings |
| `similarityThreshold` | float | `0.1` | Minimum similarity score |
| `resultLimit` | int | `50` | Max semantic hits |
| `semanticWeight` | float | `0.4` | Semantic score weight |

### Vault Settings

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `role-id` | string | from vault-agent | Vault role-id file path |
| `secret-id` | string | from vault-agent | Vault secret-id file path |
| `vault-path` | string | `"secret/campground/hister"` | Vault KV path |
| `kvVersion` | enum | `"v2"` | KV version: v1, v2 |
| `vault-address` | string | from vault-agent | Vault address |

## Vault Secrets

When using features that require secrets (access tokens, API keys), store them in Vault:

```bash
# For access token
vault kv put secret/campground/hister \
  HISTER_ACCESS_TOKEN="your-secret-token"

# For semantic search with API key
vault kv put secret/campground/hister \
  HISTER_ACCESS_TOKEN="your-secret-token" \
  HISTER_EMBEDDING_API_KEY="your-embedding-api-key"
```

## Browser Extension

Install the browser extension to automatically index your browsing history:

- [Chrome/Edge](https://chromewebstore.google.com/detail/hister/cciilamhchpmbdnniabclekddabkifhb)
- [Firefox](https://addons.mozilla.org/en-US/firefox/addon/hister/)

Configure the extension to point to your Hister instance URL and include the access token if you've configured one.

## Usage

Once the service is running:

1. **Web UI**: Navigate to `http://localhost:4433` (or your configured address)
2. **CLI**: Use the `hister` command to interact with your instance
   ```bash
   # Search
   hister search "query"
   
   # Index a URL
   hister index https://example.com
   
   # Import browser history
   hister import-browser
   ```

3. **API**: Use the REST API at `/api/*` endpoints

## Advanced Configuration

### With Custom Hotkeys

```nix
{
  fmf.services.hister = {
    enable = true;
    
    hotkeys = {
      web = {
        "/" = "focus_search_input";
        "enter" = "open_result";
        "alt+enter" = "open_result_in_new_tab";
        "alt+j" = "select_next_result";
        "alt+k" = "select_previous_result";
      };
    };
  };
}
```

### With Sensitive Content Patterns

```nix
{
  fmf.services.hister = {
    enable = true;
    
    sensitiveContentPatterns = {
      aws_access_key = "AKIA[0-9A-Z]{16}";
      github_token = "(ghp|gho|ghu|ghs|ghr)_[a-zA-Z0-9]{36}";
      custom_pattern = "SECRET_[A-Z0-9]+";
    };
  };
}
```

### With Chromium Crawler

```nix
{
  fmf.services.hister = {
    enable = true;
    
    crawler = {
      backend = "chromedp";
      backendOptions = {
        exec_path = "${pkgs.chromium}/bin/chromium";
      };
      timeout = 15;
    };
  };
}
```

## Package Requirement

This module requires a `hister` package. You'll need to add it to your packages. The upstream project provides a flake, so you can add it as an input:

```nix
# In your flake.nix
{
  inputs = {
    hister.url = "github:asciimoo/hister";
  };
  
  # Then make it available to your system
  nixosConfigurations.your-host = {
    modules = [
      {
        nixpkgs.overlays = [
          (final: prev: {
            hister = inputs.hister.packages.${prev.system}.default;
          })
        ];
      }
    ];
  };
}
```

Or build it manually and reference it:

```nix
{
  fmf.services.hister = {
    enable = true;
    package = pkgs.callPackage ./path/to/hister-package.nix {};
  };
}
```

## Service Management

```bash
# Start the service
sudo systemctl start hister

# Stop the service
sudo systemctl stop hister

# Restart the service
sudo systemctl restart hister

# View logs
sudo journalctl -u hister -f

# Check status
sudo systemctl status hister
```

## Troubleshooting

### Service won't start

Check logs: `journalctl -u hister -n 50`

### Vault secrets not loading

1. Check vault-agent service: `systemctl status vault-agent@copy-hister-env`
2. Verify secrets file: `ls -la /var/lib/vault/hister.env`
3. Check Vault path: `vault kv get secret/campground/hister`

### Database errors

If using PostgreSQL, ensure the database exists and pgvector extension is installed (for semantic search):

```sql
CREATE DATABASE hister;
\c hister
CREATE EXTENSION IF NOT EXISTS vector;
```

### Port already in use

Check what's using the port: `sudo lsof -i :4433`

Change the port in configuration:
```nix
server.address = "127.0.0.1:8080";
```

## References

- [Hister Documentation](https://hister.org/docs)
- [Hister GitHub](https://github.com/asciimoo/hister)
- [Query Language Guide](https://hister.org/docs/query-language)
- [MCP Integration](https://hister.org/docs/mcp)

## License

This module follows the fmf-flake licensing. Hister itself is licensed under AGPLv3 or later.
