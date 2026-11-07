class MockQueryResult {
  constructor(rows, rowCount, error) {
    this.rows = rows || [];
    this.rowCount = error ? 0 : (rowCount !== undefined ? rowCount : (rows ? rows.length : 0));
    this.error = error;
  }
}

class MockClient {
  constructor(responses) {
    this.responses = responses || [];
    this.index = 0;
    this.connected = false;
  }

  async connect() {
    this.connected = true;
  }

  async query(text, params) {
    if (text === 'BEGIN') return new MockQueryResult([], 0);
    if (text === 'COMMIT') return new MockQueryResult([], 0);
    if (text === 'ROLLBACK') return new MockQueryResult([], 0);

    const resp = this.responses[this.index];
    this.index++;

    if (!resp) {
      return new MockQueryResult([], 0);
    }

    if (resp.error) {
      throw resp.error;
    }

    return new MockQueryResult(resp.rows, resp.rowCount);
  }

  async release() {
    this.connected = false;
  }
}

class MockPool {
  constructor(responses) {
    this.responses = responses || [];
    this.client = new MockClient(this.responses);
  }

  async connect() {
    return this.client;
  }

  async query(text, params) {
    if (text === 'BEGIN') return new MockQueryResult([], 0);
    if (text === 'COMMIT') return new MockQueryResult([], 0);
    if (text === 'ROLLBACK') return new MockQueryResult([], 0);

    const resp = this.responses[this.index];
    this.index++;

    if (!resp) {
      return new MockQueryResult([], 0);
    }

    if (resp.error) {
      throw resp.error;
    }

    return new MockQueryResult(resp.rows, resp.rowCount);
  }

  async end() {
    // no-op
  }

  reset() {
    this.index = 0;
    this.client.index = 0;
  }
}

function crearErrorSqlstate(code, message, detail) {
  const err = new Error(message);
  err.code = code;
  err.detail = detail;
  err.hint = undefined;
  return err;
}

module.exports = { MockPool, MockClient, MockQueryResult, crearErrorSqlstate };
