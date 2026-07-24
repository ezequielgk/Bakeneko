import org.koitharu.kotatsu.parsers.model.MangaPage
fun main() {
    val methods = MangaPage::class.java.methods
    for (m in methods) {
        println(m.name)
    }
}
