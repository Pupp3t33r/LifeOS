<#macro registrationLayout bodyClass="" displayInfo=false displayMessage=true displayRequiredFields=false>
<!DOCTYPE html>
<html lang="${(locale.currentLanguageTag)!'en'}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${msg("loginTitle",(realm.displayName!''))}</title>
  <#-- Apply the stored theme choice before first paint to avoid a flash of the wrong mode.
       No choice stored => falls through to the OS prefers-color-scheme default. -->
  <script>
    (function () {
      try {
        var t = localStorage.getItem("lifeos-theme");
        if (t === "dark" || t === "light") {
          document.documentElement.setAttribute("data-theme", t);
        }
      } catch (e) {}
    })();
  </script>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="${url.resourcesPath}/css/styles.css">
  <#if scripts??>
    <#list scripts as script><script src="${script}" type="text/javascript"></script></#list>
  </#if>
  <#-- Import map required by Keycloak's WebAuthn/passkey ES modules (they import the bare
       specifier "rfc4648"). The base login template provides this; our custom template must
       too, or navigator.credentials.create/get never runs (passkey button/registration silently
       fails with "Failed to resolve module specifier rfc4648"). -->
  <script type="importmap">
    {
      "imports": {
        "rfc4648": "${url.resourcesCommonPath}/vendor/rfc4648/rfc4648.js"
      }
    }
  </script>
</head>
<body class="lifeos ${bodyClass}">
  <main class="card" role="main">
    <button type="button" id="theme-toggle" class="theme-toggle" aria-label="Toggle dark mode" title="Toggle dark mode">
      <svg class="icon-moon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>
      <svg class="icon-sun" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/></svg>
    </button>
    <div class="badge" aria-hidden="true">L</div>

    <#if displayRequiredFields>
      <div class="head-row">
        <h1 id="kc-page-title"><#nested "header"></h1>
        <span class="required-hint"><span class="req">*</span> ${msg("requiredFields")}</span>
      </div>
    <#else>
      <h1 id="kc-page-title"><#nested "header"></h1>
    </#if>

    <#if displayMessage && message?has_content && (message.type != 'warning' || !isAppInitiatedAction??)>
      <div class="alert alert-${message.type}" role="alert">
        <span class="alert-text">${kcSanitize(message.summary)?no_esc}</span>
      </div>
    </#if>

    <#nested "form">

    <#if auth?has_content && auth.showTryAnotherWayLink()>
      <form id="kc-select-try-another-way-form" action="${url.loginAction}" method="post" class="try-another-way">
        <input type="hidden" name="tryAnotherWay" value="on"/>
        <a href="#" onclick="document.forms['kc-select-try-another-way-form'].submit();return false;">${msg("doTryAnotherWay")}</a>
      </form>
    </#if>

    <#nested "socialProviders">

    <#if displayInfo>
      <div id="kc-info" class="foot">
        <#nested "info">
      </div>
    </#if>

    <#if realm.internationalizationEnabled && locale.supported?size gt 1>
      <div class="locale" id="kc-locale">
        <#list locale.supported as l>
          <a href="${l.url}" aria-current="<#if locale.currentLanguageTag == l.languageTag>true<#else>false</#if>">${l.label}</a>
        </#list>
      </div>
    </#if>
  </main>
  <#-- Wire the toggle: flip the resolved mode and remember it on this (Keycloak) origin. -->
  <script>
    (function () {
      var btn = document.getElementById("theme-toggle");
      if (!btn) return;
      var root = document.documentElement;
      function resolved() {
        var attr = root.getAttribute("data-theme");
        if (attr === "dark" || attr === "light") return attr;
        return (window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches) ? "dark" : "light";
      }
      function apply(mode) {
        root.setAttribute("data-theme", mode);
        try { localStorage.setItem("lifeos-theme", mode); } catch (e) {}
        btn.setAttribute("aria-pressed", String(mode === "dark"));
      }
      btn.setAttribute("aria-pressed", String(resolved() === "dark"));
      btn.addEventListener("click", function () {
        apply(resolved() === "dark" ? "light" : "dark");
      });
    })();
  </script>
</body>
</html>
</#macro>
