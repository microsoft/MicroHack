(function () {
  // In development, the API url is built in api/config.ts
  // In production containers, this file is overwritten by `entrypoint.sh`.
  window.RUNTIME_CONFIG = Object.assign({}, window.RUNTIME_CONFIG, { API_URL: undefined });
})();
