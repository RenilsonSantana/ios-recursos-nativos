//
//  HomeTableViewController.swift
//  Agenda
//
//  Created by Ândriu Coelho on 24/11/17.
//  Copyright © 2017 Alura. All rights reserved.
//

import UIKit
import CoreData
import SafariServices

class HomeTableViewController: UITableViewController, UISearchBarDelegate, NSFetchedResultsControllerDelegate {
    
    //MARK: - Variáveis
    var context:NSManagedObjectContext {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        return appDelegate.persistentContainer.viewContext
    }
    
    var gerenciadorDeResultados: NSFetchedResultsController<Aluno>?
    
    let searchController = UISearchController(searchResultsController: nil)
    
    var alunoViewController: AlunoViewController?
    
    let mensagem = Mensagem()
    
    // MARK: - IBActions
    
    @IBAction func buttonMedia(_ sender: Any) {
        guard let listaDeAlunos = gerenciadorDeResultados?.fetchedObjects else { return }
        CalculaMediaAPI().calculaMediaGeralDosAlunos(alunos: listaDeAlunos, sucesso: { (dicionario) in
            if let alerta = Notificacoes().exibeNotificacaoDeMediaDosAlunos(dicionarioDeMedia: dicionario) {
                self.present(alerta, animated: true, completion: nil)
            }
        }) { (error) in
            print(error.localizedDescription
            )
        }
            
    }
    
    @IBAction func buttonLocalizacaoGeral(_ sender: Any) {
        let mapa = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "mapa") as! MapaViewController
        navigationController?.pushViewController(mapa, animated: true)
    }
    
    
    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.configuraSearch()
        self.recuperaAluno()
    }
    
    // MARK: - Métodos
    
    func configuraSearch() {
        self.searchController.searchBar.delegate = self
        self.searchController.dimsBackgroundDuringPresentation = false
        self.navigationItem.searchController = searchController
    }
    
    func recuperaAluno(filtro:String = ""){
        let pesquisaAluno: NSFetchRequest<Aluno> = Aluno.fetchRequest()
        let ordenaPorNome = NSSortDescriptor(key: "nome", ascending: true)
        pesquisaAluno.sortDescriptors = [ordenaPorNome]
        
        if verificaFiltro(filtro){
            pesquisaAluno.predicate = filtraAluno(filtro)
        }
        
        gerenciadorDeResultados = NSFetchedResultsController(fetchRequest: pesquisaAluno, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        
        gerenciadorDeResultados?.delegate = self
        
        do{
            try gerenciadorDeResultados?.performFetch()
        } catch{
            print(error.localizedDescription)
        }
    }
    
    @objc func abrirActionSheet(_ longPress: UILongPressGestureRecognizer){
        if longPress.state == .began{
            //Pegando dados do aluno selecionado
            guard let alunoSelecionado = gerenciadorDeResultados?.fetchedObjects?[(longPress.view?.tag)!] else { return }
            let menu = MenuOpcoesAlunos().configuraMenuDeOpcoesDoAluno(completion: { (opcao) in
                switch opcao{
                case .sms:
                    if let componenteMensagem = self.mensagem.configuraSMS(alunoSelecionado){
                        componenteMensagem.messageComposeDelegate = self.mensagem
                        self.present(componenteMensagem, animated: true, completion: nil)
                    }
                    break
                case .ligacao:
                    guard  let numeroDoAluno = alunoSelecionado.telefone else { return }
                    if let url = URL(string: "tel://\(numeroDoAluno)"), UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                    break
                case .waze:
                    //Verificando se tem Waze instalado no iPhone
                    if UIApplication.shared.canOpenURL(URL(string: "waze://")!){
                        guard let enderecoDoAluno = alunoSelecionado.endereco else { return }
                        Localizacao().converteEnderecoEmCoordenadas(endereco: enderecoDoAluno, local: { (localicacaoEncontrada) in
                            let latitude = String(describing: localicacaoEncontrada.location!.coordinate.latitude)
                            let longitude = String(describing: localicacaoEncontrada.location!.coordinate.longitude)
                            let url: String = "waze://?ll\(latitude),\(longitude)&navigate=yes"
                            UIApplication.shared.open(URL(string: url)!, options: [:], completionHandler: nil)
                        })
                    }
                    break
                case .mapa:
                    let mapa = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "mapa") as! MapaViewController
                    mapa.aluno = alunoSelecionado
                    self.navigationController?.pushViewController(mapa, animated: true)
                    break
                case .abrirWebSite:
                    if let urlDoAluno = alunoSelecionado.site{
                        var urlFormatada = urlDoAluno
                        
                        if !urlFormatada.hasPrefix("https://"){
                            urlFormatada = String(format: "https://%@", urlFormatada)
                        }
                        
                        guard let url = URL(string: urlFormatada) else { return }
                        let safariViewController = SFSafariViewController(url: url)
                        self.present(safariViewController, animated: true, completion: nil)
                    }
                    break
                }
            })
            self.present(menu, animated: true, completion: nil)
        }
    }
    
    func filtraAluno(_ filtro:String) -> NSPredicate{
        return NSPredicate(format: "nome CONTAINS %@", filtro)
    }
    
    func verificaFiltro(_ filtro:String) -> Bool{
        if filtro.isEmpty{
            return false
        }
        return true
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let contadorListaDeAluno = gerenciadorDeResultados?.fetchedObjects?.count else { return 0}
        return contadorListaDeAluno
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "celula-aluno", for: indexPath) as! HomeTableViewCell
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(abrirActionSheet(_:)))

        guard let aluno = gerenciadorDeResultados?.fetchedObjects![indexPath.row] else { return cell }
        cell.configuraCelula(aluno)
        cell.tag = indexPath.row
        
        cell.addGestureRecognizer(longPress)
        
        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            AutenticacaoLocal().autorizacaoUsuario(completion: { (autenticado) in
                if autenticado{
                    DispatchQueue.main.async {
                        guard let alunoSelecionado = self.gerenciadorDeResultados?.fetchedObjects![indexPath.row] else { return }
                        self.context.delete(alunoSelecionado)
                        do{
                            try self.context.save()
                        } catch{
                            print(error.localizedDescription)
                        }
                        tableView.deleteRows(at: [indexPath], with: .fade)
                    }
                }
            })
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 85
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "editar"{
            alunoViewController = segue.destination as? AlunoViewController
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let alunoSelecionado = gerenciadorDeResultados?.fetchedObjects![indexPath.row] else { return }
        alunoViewController?.aluno = alunoSelecionado
    }
    
    // MARK: - NSFetchedResultsController
    
    //Metodo que execulta apos alguma modificacão na CoreData
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type{
        case .delete:
            // implementar
            break
        default:
            tableView.reloadData()
        }
    }
    
    // MARK: - SearchBarDelegate
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let nomeDoAluno = searchBar.text else { return }
        recuperaAluno(filtro: nomeDoAluno)
        tableView.reloadData()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        recuperaAluno()
        tableView.reloadData()
    }

}
