const networkDashboardHtml = r'''<!doctype html>
<html lang="pt-BR">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <title>LC Carga · Acesso pela rede</title>
    <style nonce="__NONCE__">
      * {
        box-sizing: border-box;
      }
      [hidden] {
        display: none !important;
      }
      body {
        margin: 0;
        background: #f4f5fb;
        color: #24243b;
        font:
          16px system-ui,
          -apple-system,
          Segoe UI,
          sans-serif;
      }
      main {
        max-width: 1040px;
        margin: auto;
        padding: 24px;
      }
      header {
        padding: 30px 24px;
        border-radius: 24px;
        background: linear-gradient(115deg, #6c63ff, #4ecdc4);
        color: white;
        margin-bottom: 22px;
      }
      h1 {
        margin: 0 0 6px;
        font-size: 28px;
      }
      header p {
        margin: 0;
        opacity: 0.95;
      }
      .panel,
      details {
        background: white;
        border: 1px solid #e7e7f3;
        border-radius: 20px;
        padding: 24px;
        margin-bottom: 16px;
      }
      h2 {
        margin: 0 0 18px;
        font-size: 22px;
      }
      label {
        display: block;
        font-weight: 650;
        margin: 0 0 7px;
      }
      input,
      textarea {
        width: 100%;
        padding: 13px;
        border: 1px solid #c8cadb;
        border-radius: 12px;
        font: inherit;
        background: #fafaff;
        color: inherit;
      }
      input:focus,
      textarea:focus {
        outline: 3px solid #6c63ff38;
        border-color: #6c63ff;
      }
      textarea {
        font:
          13px ui-monospace,
          monospace;
        min-height: 90px;
        resize: vertical;
        word-break: break-all;
      }
      button {
        border: 0;
        border-radius: 12px;
        padding: 12px 18px;
        font: inherit;
        font-weight: 650;
        cursor: pointer;
        background: #6c63ff;
        color: white;
      }
      button:disabled {
        opacity: 0.6;
        cursor: wait;
      }
      .secondary {
        background: #ecebff;
        color: #534acb;
      }
      .field {
        margin-bottom: 18px;
      }
      .row {
        display: flex;
        gap: 16px;
        align-items: center;
        flex-wrap: wrap;
      }
      .row > .field {
        flex: 1;
        min-width: 180px;
      }
      .muted {
        font-size: 14px;
        color: #696b81;
      }
      .notice {
        padding: 14px 18px;
        border-radius: 12px;
        background: #fff0ef;
        color: #a42a22;
        margin-bottom: 16px;
      }
      .success {
        background: #e9f8ef;
        color: #216342;
      }
      nav {
        display: flex;
        gap: 8px;
        flex-wrap: wrap;
        margin-bottom: 20px;
      }
      nav button {
        flex: 1;
        background: white;
        color: #696b81;
        border: 1px solid #e7e7f3;
      }
      nav button[aria-pressed="true"] {
        background: #ecebff;
        color: #534acb;
        border-color: #c8c1ff;
      }
      fieldset {
        border: 0;
        margin: 0;
        padding: 0;
        min-width: 0;
      }
      summary {
        cursor: pointer;
        font-weight: 750;
        list-style: none;
        display: flex;
        align-items: center;
        gap: 10px;
      }
      summary::before {
        content: "📁";
      }
      details[open] > summary::before {
        content: "📂";
      }
      summary .count {
        font-size: 13px;
        font-weight: 500;
        color: #696b81;
        margin-left: auto;
      }
      .activation {
        border: 1px solid #dedfec;
        border-radius: 16px;
        padding: 18px;
        margin-top: 16px;
      }
      .activation h3 {
        margin: 0 0 8px;
        overflow-wrap: anywhere;
      }
      .activation p {
        margin: 7px 0;
      }
      .tag {
        display: inline-block;
        padding: 4px 9px;
        border-radius: 9px;
        background: #e9f8ef;
        color: #216342;
        font-size: 13px;
      }
      .tag.expired {
        background: #fff0ef;
        color: #a42a22;
      }
      .code-row {
        margin-top: 12px;
      }
      .code-row button {
        margin-top: 8px;
      }
      .toolbar {
        display: flex;
        align-items: center;
        gap: 12px;
        margin-bottom: 18px;
        flex-wrap: wrap;
      }
      .toolbar p {
        flex: 1;
        margin: 0;
      }
      .login {
        max-width: 470px;
        margin: 24px auto;
      }
      .empty {
        color: #696b81;
        padding: 22px 0;
      }
      .result {
        border: 1px solid #a2d9b9;
        background: #f3fcf6;
        border-radius: 16px;
        padding: 18px;
        margin-top: 24px;
      }
      footer {
        text-align: center;
        font-size: 13px;
        color: #696b81;
        padding: 16px;
      }
      @media (max-width: 560px) {
        main {
          padding: 12px;
        }
        .panel,
        details {
          padding: 18px;
        }
        header {
          padding: 24px 20px;
        }
        .row {
          display: block;
        }
        nav button {
          padding: 12px 8px;
          font-size: 14px;
        }
      }
    </style>
  </head>
  <body>
    <main>
      <header>
        <h1>LC Carga</h1>
        <p>Gerador de licenças · Acesso pela rede</p>
      </header>
      <section id="login" class="panel login">
        <h2>Entrar</h2>
        <p class="muted">Use a senha exibida na aba Rede do aplicativo no computador.</p>
        <form id="login-form">
          <div class="field">
            <label for="password">Senha de acesso</label
            ><input
              id="password"
              type="password"
              autocomplete="current-password"
              required
              maxlength="512"
            />
          </div>
          <p id="login-error" class="notice" role="alert" hidden></p>
          <button type="submit">Acessar</button>
        </form>
      </section>
      <section id="dashboard" hidden>
        <div class="toolbar">
          <p class="muted">
            Dados compartilhados com o computador que está executando o aplicativo.
          </p>
          <button id="refresh" class="secondary" type="button">Atualizar</button
          ><button id="logout" class="secondary" type="button">Sair</button>
        </div>
        <p id="notice" class="notice" role="status" hidden></p>
        <nav aria-label="Seções">
          <button type="button" data-tab="generate" aria-pressed="true">Gerar</button
          ><button type="button" data-tab="history" aria-pressed="false">Histórico</button
          ><button type="button" data-tab="expired" aria-pressed="false">Expiradas</button>
        </nav>
        <section id="generate" class="panel">
          <h2>Gerar licença</h2>
          <form id="generate-form">
            <fieldset>
              <div class="field">
                <label for="customer">Cliente (ID único)</label
                ><input id="customer" required maxlength="256" placeholder="Ex.: empresa_123" />
              </div>
              <div class="field">
                <label for="hardware">Código da máquina</label
                ><input
                  id="hardware"
                  required
                  maxlength="1024"
                  placeholder="Cole o código exibido no LC Carga"
                />
              </div>
              <div class="row">
                <div class="field">
                  <label for="months">Validade (meses)</label
                  ><input id="months" type="number" min="1" step="1" value="1" required />
                </div>
                <div class="field">
                  <label for="amount">Valor (R$)</label
                  ><input
                    id="amount"
                    inputmode="decimal"
                    maxlength="40"
                    placeholder="Ex.: 150,00"
                  /><small class="muted">Opcional</small>
                </div>
              </div>
              <p class="muted">A ativação será salva no histórico compartilhado.</p>
              <button type="submit">Gerar licença</button>
            </fieldset>
          </form>
          <div id="result" class="result" hidden>
            <h3>Licença gerada e salva</h3>
            <p id="result-info"></p>
            <label for="result-code">Código da licença</label
            ><textarea id="result-code" readonly></textarea
            ><button id="copy-result" class="secondary" type="button">Copiar chave</button>
          </div>
        </section>
        <section id="history" hidden>
          <div class="panel">
            <h2>Histórico de ativações</h2>
            <p id="history-count" class="muted"></p>
          </div>
          <div id="history-list"></div>
        </section>
        <section id="expired" hidden>
          <div class="panel">
            <h2>Chaves expiradas</h2>
            <p id="expired-count" class="muted"></p>
          </div>
          <div id="expired-list"></div>
        </section>
      </section>
      <footer>
        O computador e o aplicativo precisam permanecer ligados para manter este acesso.
      </footer>
    </main>
    <script nonce="__NONCE__">
      "use strict";
      const $ = (id) => document.getElementById(id);
      let token = "",
        entries = [],
        refreshSequence = 0,
        serverOffset = 0;
      try {
        token = sessionStorage.getItem("lc-network-token") || "";
      } catch (_) {}
      const dateFormat = new Intl.DateTimeFormat("pt-BR");
      const monthFormat = new Intl.DateTimeFormat("pt-BR", { month: "long", year: "numeric" });
      const moneyFormat = new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" });
      function validDate(value) {
        if (!value) return null;
        const date = new Date(value);
        return Number.isNaN(date.getTime()) ? null : date;
      }
      function money(entry) {
        return entry.amountCents == null
          ? "Não informado"
          : moneyFormat.format(entry.amountCents / 100);
      }
      function notice(message, success = false) {
        $("notice").textContent = message;
        $("notice").className = success ? "notice success" : "notice";
        $("notice").hidden = !message;
      }
      function showLogin(message = "") {
        token = "";
        try {
          sessionStorage.removeItem("lc-network-token");
        } catch (_) {}
        $("dashboard").hidden = true;
        $("login").hidden = false;
        $("login-error").textContent = message;
        $("login-error").hidden = !message;
        entries = [];
        render();
        $("result-code").value = "";
        $("result").hidden = true;
      }
      async function api(path, options = {}) {
        let response;
        try {
          response = await fetch(path, {
            ...options,
            headers: {
              Authorization: "Bearer " + token,
              "Content-Type": "application/json",
              ...(options.headers || {}),
            },
            cache: "no-store",
          });
        } catch (_) {
          throw new Error(
            "Sem conexão com o computador. Verifique se o aplicativo continua aberto.",
          );
        }
        const data = await response.json();
        if (!response.ok) {
          const error = new Error(data.error || "Não foi possível concluir a operação.");
          error.status = response.status;
          throw error;
        }
        return data;
      }
      async function refresh() {
        const accessToken = token,
          sequence = ++refreshSequence;
        const data = await api("/api/history");
        if (accessToken !== token || sequence !== refreshSequence) return;
        serverOffset = Date.parse(data.serverTime) - Date.now();
        entries = data.entries;
        render();
      }
      function showApp() {
        $("login").hidden = true;
        $("dashboard").hidden = false;
        $("password").value = "";
        try {
          sessionStorage.setItem("lc-network-token", token);
        } catch (_) {}
      }
      function handleError(error) {
        if (error.status === 401) {
          showLogin("A senha de acesso mudou ou não é válida. Entre novamente.");
        } else {
          notice(error.message);
        }
      }
      function addText(parent, tag, text, className = "") {
        const node = document.createElement(tag);
        node.textContent = text;
        if (className) node.className = className;
        parent.appendChild(node);
        return node;
      }
      async function copyCode(textarea) {
        try {
          if (navigator.clipboard && window.isSecureContext) {
            await navigator.clipboard.writeText(textarea.value);
          } else {
            textarea.focus();
            textarea.select();
            if (!document.execCommand("copy")) throw new Error();
          }
          notice("Chave copiada.", true);
        } catch (_) {
          textarea.focus();
          textarea.select();
          notice("O código está selecionado. Use a opção Copiar do seu dispositivo.");
        }
      }
      function renderList(container, list, isExpired) {
        const opened = new Set(
          [...container.querySelectorAll("details[open]")].map((node) => node.dataset.month),
        );
        container.replaceChildren();
        const groups = new Map();
        for (const entry of list) {
          const date = validDate(entry.createdAt);
          const key = date
            ? date.getFullYear() + "-" + String(date.getMonth() + 1).padStart(2, "0")
            : "undated";
          if (!groups.has(key)) groups.set(key, { date, entries: [] });
          groups.get(key).entries.push(entry);
        }
        const keys = [...groups.keys()].sort((a, b) =>
          a === "undated" ? 1 : b === "undated" ? -1 : b.localeCompare(a),
        );
        if (!keys.length) {
          addText(
            container,
            "p",
            isExpired ? "Nenhuma chave expirada." : "Nenhuma ativação registrada.",
            "empty",
          );
          return;
        }
        for (const key of keys) {
          const group = groups.get(key);
          const folder = document.createElement("details");
          folder.dataset.month = key;
          folder.open = opened.has(key);
          const summary = document.createElement("summary");
          const label = group.date ? monthFormat.format(group.date) : "Sem data de geração";
          addText(summary, "span", label.charAt(0).toUpperCase() + label.slice(1));
          addText(
            summary,
            "span",
            group.entries.length + (group.entries.length === 1 ? " ativação" : " ativações"),
            "count",
          );
          folder.appendChild(summary);
          for (const entry of group.entries) {
            const card = document.createElement("article");
            card.className = "activation";
            addText(card, "h3", entry.customerId);
            const validity = validDate(entry.validity),
              created = validDate(entry.createdAt);
            addText(
              card,
              "span",
              !validity ? "Indefinida" : isExpired ? "Expirada" : "Ativa",
              "tag" + (isExpired ? " expired" : ""),
            );
            if (created) addText(card, "p", "Gerada em: " + dateFormat.format(created), "muted");
            addText(
              card,
              "p",
              "Validade: " + (validity ? dateFormat.format(validity) : "Não informada"),
              "muted",
            );
            addText(card, "p", "Valor: " + money(entry));
            const codeRow = document.createElement("div");
            codeRow.className = "code-row";
            const code = document.createElement("textarea");
            code.value = entry.code;
            code.readOnly = true;
            code.setAttribute("aria-label", "Chave de " + entry.customerId);
            codeRow.appendChild(code);
            const button = addText(codeRow, "button", "Copiar chave", "secondary");
            button.type = "button";
            button.addEventListener("click", () => copyCode(code));
            card.appendChild(codeRow);
            folder.appendChild(card);
          }
          container.appendChild(folder);
        }
      }
      function render() {
        const now = Date.now() + serverOffset,
          current = [],
          expired = [];
        for (const entry of entries) {
          const date = validDate(entry.validity);
          (date && date.getTime() <= now ? expired : current).push(entry);
        }
        renderList($("history-list"), current, false);
        renderList($("expired-list"), expired, true);
        $("history-count").textContent = current.length + " ativações no histórico";
        $("expired-count").textContent = expired.length + " chaves expiradas";
      }
      $("login-form").addEventListener("submit", async (event) => {
        event.preventDefault();
        const button = event.target.querySelector("button");
        button.disabled = true;
        token = $("password").value;
        try {
          await refresh();
          showApp();
          $("login-error").hidden = true;
        } catch (error) {
          showLogin(error.status === 401 ? "Senha de acesso incorreta." : error.message);
        } finally {
          button.disabled = false;
        }
      });
      $("generate-form").addEventListener("submit", async (event) => {
        event.preventDefault();
        const fieldset = event.target.querySelector("fieldset");
        fieldset.disabled = true;
        notice("");
        $("result").hidden = true;
        try {
          const entry = await api("/api/licenses", {
            method: "POST",
            body: JSON.stringify({
              customerId: $("customer").value,
              hardwareId: $("hardware").value,
              months: Number($("months").value),
              amount: $("amount").value,
            }),
          });
          $("result-code").value = entry.code;
          $("result-info").textContent =
            "Cliente: " +
            entry.customerId +
            " · Validade: " +
            dateFormat.format(new Date(entry.validity)) +
            " · Valor: " +
            money(entry);
          $("result").hidden = false;
          notice("Licença gerada e salva no computador.", true);
          await refresh();
        } catch (error) {
          handleError(error);
        } finally {
          fieldset.disabled = false;
        }
      });
      for (const button of document.querySelectorAll("[data-tab]"))
        button.addEventListener("click", () => {
          for (const tab of document.querySelectorAll("[data-tab]")) {
            const selected = tab === button;
            tab.setAttribute("aria-pressed", String(selected));
            $(tab.dataset.tab).hidden = !selected;
          }
          render();
        });
      $("copy-result").addEventListener("click", () => copyCode($("result-code")));
      $("refresh").addEventListener("click", async () => {
        try {
          await refresh();
          notice("Dados atualizados.", true);
        } catch (error) {
          handleError(error);
        }
      });
      $("logout").addEventListener("click", () => showLogin());
      setInterval(() => {
        if (token && !$("dashboard").hidden && !document.hidden) refresh().catch(handleError);
      }, 10000);
      document.addEventListener("visibilitychange", () => {
        if (!document.hidden && token && !$("dashboard").hidden) refresh().catch(handleError);
      });
      if (token)
        refresh()
          .then(showApp)
          .catch((error) =>
            showLogin(
              error.status === 401 ? "Entre com a senha exibida no aplicativo." : error.message,
            ),
          );
    </script>
  </body>
</html>
''';
