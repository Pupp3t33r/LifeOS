<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('username','password') displayInfo=realm.password && realm.registrationAllowed && !registrationDisabled??; section>
  <#if section = "header">
    ${msg("loginAccountTitle")}
  <#elseif section = "form">
    <p class="sub">${msg("loginSubtitle")}</p>
    <#if realm.password>
      <form id="kc-form-login" onsubmit="login.disabled = true; return true;" action="${url.loginAction}" method="post">
        <#if !usernameHidden??>
          <div class="field">
            <label for="username">
              <#if !realm.loginWithEmailAllowed>${msg("username")}
              <#elseif !realm.registrationEmailAsUsername>${msg("usernameOrEmail")}
              <#else>${msg("email")}</#if>
            </label>
            <input tabindex="1" id="username" name="username" value="${(login.username!'')}" type="text" autofocus autocomplete="username"
                   aria-invalid="<#if messagesPerField.existsError('username','password')>true</#if>"/>
            <#if messagesPerField.existsError('username','password')>
              <span class="field-error" aria-live="polite">${kcSanitize(messagesPerField.getFirstError('username','password'))?no_esc}</span>
            </#if>
          </div>
        </#if>

        <div class="field">
          <label for="password">${msg("password")}</label>
          <input tabindex="2" id="password" name="password" type="password" autocomplete="current-password"
                 aria-invalid="<#if messagesPerField.existsError('username','password')>true</#if>"/>
          <#if usernameHidden?? && messagesPerField.existsError('username','password')>
            <span class="field-error" aria-live="polite">${kcSanitize(messagesPerField.getFirstError('username','password'))?no_esc}</span>
          </#if>
        </div>

        <div class="row">
          <#if realm.rememberMe && !usernameHidden??>
            <label class="check">
              <input tabindex="3" id="rememberMe" name="rememberMe" type="checkbox" <#if login.rememberMe??>checked</#if>/> ${msg("rememberMe")}
            </label>
          <#else>
            <span></span>
          </#if>
          <#if realm.resetPasswordAllowed>
            <a tabindex="5" href="${url.loginResetCredentialsUrl}">${msg("doForgotPassword")}</a>
          </#if>
        </div>

        <input type="hidden" id="id-hidden-input" name="credentialId" <#if auth.selectedCredential?has_content>value="${auth.selectedCredential}"</#if>/>
        <button tabindex="4" class="btn" name="login" id="kc-login" type="submit">${msg("doLogIn")}</button>
      </form>
    </#if>
  <#elseif section = "socialProviders">
    <#if realm.password && social?? && social.providers?has_content>
      <div class="div">${msg("identity-provider-login-label")}</div>
      <div class="social-list">
        <#list social.providers as p>
          <a id="social-${p.alias}" class="social" href="${p.loginUrl}">
            <#if p.iconClasses?has_content><i class="${p.iconClasses}" aria-hidden="true"></i></#if>
            <span>${p.displayName!}</span>
          </a>
        </#list>
      </div>
    </#if>
  <#elseif section = "info">
    <#if realm.password && realm.registrationAllowed && !registrationDisabled??>
      ${msg("noAccount")} <a tabindex="6" href="${url.registrationUrl}">${msg("doRegister")}</a>
    </#if>
  </#if>
</@layout.registrationLayout>
