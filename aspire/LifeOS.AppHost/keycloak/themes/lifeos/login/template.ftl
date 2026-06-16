<#macro registrationLayout bodyClass="" displayInfo=false displayMessage=true displayRequiredFields=false>
<!DOCTYPE html>
<html lang="${locale.currentLanguageTag}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${msg("loginTitle",(realm.displayName!''))}</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,500;12..96,700&family=Spline+Sans:wght@400;500;600&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="${url.resourcesPath}/css/styles.css">
  <#if scripts??>
    <#list scripts as script><script src="${script}" type="text/javascript"></script></#list>
  </#if>
</head>
<body class="lifeos ${bodyClass}">
  <main class="card" role="main">
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
</body>
</html>
</#macro>
