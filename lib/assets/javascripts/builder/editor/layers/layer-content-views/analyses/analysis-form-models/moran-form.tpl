<form>
  <div class="Editor-HeaderInfo">
    <div class="Editor-HeaderNumeration CDB-Text is-semibold u-rSpace--m">1</div>
    <div class="Editor-HeaderInfo-inner CDB-Text">
      <div class="Editor-HeaderInfo-title u-bSpace--m">
        <h2 class="CDB-Text CDB-HeaderInfo-titleText CDB-Size-large"><%- _t('analyses.moran-cluster.title') %></h2>
      </div>
      <div class="Editor-HeaderInfo-subtitle u-bSpace--m">
        <%= linkContent %><p class="CDB-Text CDB-FontSize-small u-upperCase u-altTextColor"><%- _t('editor.layers.analysis-form.input-layer') %></p>
      </div>
      <div data-fields="source,numerator_column,denominator_column,significance,neighbours"></div>
    </div>
  </div>
</form>