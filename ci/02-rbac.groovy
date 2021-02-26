import com.cloudbees.hudson.plugins.folder.*
import hudson.security.HudsonPrivateSecurityRealm
import jenkins.model.Jenkins
import nectar.plugins.rbac.groups.*

import java.util.logging.Logger

String scriptName = "init.rbac.groovy"
int version = 1

int markerVersion = 0
Logger logger = Logger.getLogger(scriptName)

File disableScript = new File(Jenkins.getInstance().getRootDir(), ".disable-authorization-script")
if (disableScript.exists()) {
    logger.info("DISABLE authorization script")
    return
}

File markerFile = new File(Jenkins.getInstance().getRootDir(), ".${scriptName}.done")
if (markerFile.exists()) {
    markerVersion = markerFile.text.toInteger()
}
if (markerVersion == version) {
    logger.info("$scriptName has already been executed for version $version, skipping execution");
    return
}

logger.info("Migrating from version $markerVersion to version $version")

Jenkins jenkins = Jenkins.getInstance()

HudsonPrivateSecurityRealm hudsonPrivateSecurityRealm = new HudsonPrivateSecurityRealm(false, false, null)
hudsonPrivateSecurityRealm.createAccount("admin", "changeit")
jenkins.setSecurityRealm(hudsonPrivateSecurityRealm)
