import org.gradle.api.Project
import java.io.File
import java.util.*

object SigningHelper {

    fun loadSigningConfig(project: Project): Config? {
        return loadFromGradleProperties(project)
            ?: loadFromPropertiesFile(project)
            ?: loadFromEnvironment(project)
    }

    private fun loadFromGradleProperties(project: Project): Config? {
        val storeFile = project.findProperty("signing.storeFile")?.toString() ?: return null
        val storePassword = project.findProperty("signing.storePassword")?.toString() ?: return null
        val keyAlias = project.findProperty("signing.keyAlias")?.toString() ?: return null
        val keyPassword = project.findProperty("signing.keyPassword")?.toString() ?: return null

        return buildConfig(project, storeFile, storePassword, keyAlias, keyPassword)
    }

    private fun loadFromPropertiesFile(project: Project): Config? {
        val propertiesFile = project.rootProject.file("keystore.properties")
        if (!propertiesFile.exists()) return null

        val properties = Properties().apply {
            propertiesFile.inputStream().use(::load)
        }

        val storeFile = properties.getProperty("storeFile") ?: return null
        val storePassword = properties.getProperty("storePassword") ?: return null
        val keyAlias = properties.getProperty("keyAlias") ?: return null
        val keyPassword = properties.getProperty("keyPassword") ?: return null

        return buildConfig(project, storeFile, storePassword, keyAlias, keyPassword)
    }

    private fun loadFromEnvironment(project: Project): Config? {
        val storeFile = System.getenv("KEYSTORE_FILE")?.let { resolveStoreFile(project, it) }
            ?: loadSerializedStoreFile(project)
            ?: return null
        val storePassword = System.getenv("KEYSTORE_PASSWORD") ?: return null
        val keyAlias = System.getenv("KEY_ALIAS") ?: return null
        val keyPassword = System.getenv("KEY_PASSWORD") ?: return null

        return Config(storeFile, storePassword, keyAlias, keyPassword)
    }

    private fun loadSerializedStoreFile(project: Project): File? {
        val serializedKeystore = System.getenv("KEYSTORE") ?: return null
        return try {
            project.rootProject.layout.buildDirectory.file("signing/keystore.jks").get().asFile.apply {
                parentFile.mkdirs()
                writeBytes(Base64.getDecoder().decode(serializedKeystore))
            }
        } catch (e: RuntimeException) {
            null
        }
    }

    private fun buildConfig(
        project: Project,
        storeFilePath: String,
        storePassword: String,
        keyAlias: String,
        keyPassword: String,
    ): Config? {
        val storeFile = resolveStoreFile(project, storeFilePath) ?: return null

        return Config(storeFile, storePassword, keyAlias, keyPassword)
    }

    private fun resolveStoreFile(project: Project, path: String): File? {
        val candidates = listOf(
            File(path),
            project.rootProject.file(path),
            project.file(path),
        )

        return candidates.firstOrNull(File::exists)
    }

    data class Config(
        /**
         * Store file used when signing.
         */
        val storeFile: File,

        /**
         * Store password used when signing.
         */
        val storePassword: String,

        /**
         * Key alias used when signing.
         */
        val keyAlias: String,

        /**
         * Key password used when signing.
         */
        val keyPassword: String
    )
}
