<?php namespace PhpProxySks\Keyserver\Skin;

use PhpProxySks\Keyserver;
use PhpProxySks\Keyserver\Log;

class Phtml {

  private $_page;
  private $_content;

  public function __construct($page, $content = FALSE) {
    $this->_page = (string)$page;
    if ($content)
      $this->_content = self::_importData($content);
  }

  public function __toString() {
    try {
      return $this->_parsePhtml($this->_getSkinPath().((
        strpos($this->_page, '/errors/')===0
        and !Keyserver::getConfig()->layout_404
      ) ? '/plain_'.ltrim($this->_page,'/') : '/skin_layout' ).'.phtml');
    } catch (\Exception $e) {
      Log::catchError($e);
      return "";
    }
  }

  public static function _importData($content) {
    $dom = new \DOMDocument('1.0');
    libxml_use_internal_errors(true);
    if (!$dom->loadHTML(utf8_encode($content))) {
      $_error = "Validation of Strict HTML failed:";
      foreach(libxml_get_errors() as $error)
        $_error .= "\n\t".$error->message;
      Log::catchError($_error);
      return preg_replace('/.*<body>(.*)<\/body>.*$/s', '$1', $content);
    }
    $xpath = new \DOMXPath($dom);
    $body = $xpath->query('/html/body');
    return preg_replace('/^<body>(.*)<\/body>$/s', '$1',
      utf8_decode($dom->saveXml($body->item(0)))
    );
  }

  private function _getSkinPath() {
    return '../skin/'.Keyserver::getConfig()->html_skin;
  }

  private function _parsePhtml($file) {
    if (strpos(realpath($file), realpath($this->_getSkinPath()))!==0)
      throw new \Exception('Unknown skin path: "'.$file.'".');

    ob_start();
    include($file);
    return ob_get_clean();
  }

  private function getConfig($key) {
    if (!property_exists($config = Keyserver::getConfig(), $key))
      throw new \Exception('Unknown config: "'.$key.'".');

    return $config->{$key};
  }

  private function getBlock($phtml) {
    if (!is_readable($file = realpath(
      $path = $this->_getSkinPath().'/blocks/'.$phtml.'.phtml'
    )))
      throw new \Exception('Unknown block: "'.$path.'".');

    return $this->_parsePhtml($file);
  }

  private function getPage($phtml = NULL) {
    if (is_null($phtml)) {
      if (!$this->_page and $this->_content)
        return $this->_content;
      $phtml = $this->_page;
    }

    if (!is_readable($file = realpath(
      $path = $this->_getSkinPath().'/pages/'.ltrim($phtml, '/').'.phtml'
    )))
      throw new \Exception('Unknown page: "'.$path.'".');

    return $this->_parsePhtml($file);
  }
}
